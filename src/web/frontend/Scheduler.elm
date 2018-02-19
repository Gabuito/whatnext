module Scheduler exposing (..)

--view imports

import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, placeholder, type_, id, class, value, required)
import Html.Styled.Events exposing (..)
import Html.Events.Extra exposing (targetValueIntParse)
import Dom.Scroll
import Toaster exposing (..)
import Css exposing (..)
import Colors exposing (defaultColors)


-- json

import Json.Decode
import Json.Encode
import Json.Decode exposing (..)
import Json.Decode.Pipeline


--rest

import Http exposing (..)
import Platform exposing (..)
import Array exposing (Array)
import Task
import Subject exposing (Subject, StudyEntry, DoneData)


main =
    Html.programWithFlags { init = init, view = view >> Html.Styled.toUnstyled, update = update, subscriptions = subscriptions }


init : Flags -> ( State, Cmd Msg )
init flags =
    ( State [] Nothing True "" False flags.apiEndpoint "" "" "" False 50 50 "", getListRequest flags.apiEndpoint False )



-- Model


type Msg
    = NewList (Result Http.Error (Array Subject))
    | ToggleTiredMode
    | None
    | MySubjectMsg SubjectMsg
    | ToggleAddSubjectModal
    | ChangeNewSubjectName String
    | ChangeNewPriority Int
    | ChangeNewComplexity Int
    | SubmitNewSubject
    | NewSubjectResult (Result Http.Error String)


type SubjectMsg
    = ExpandSubjectClick ( Int, Subject )
    | Remove (Result Http.Error String)
    | RemoveClick Subject
    | GetDetail (Result Http.Error Subject)
    | MyDoneMsg DoneMsg


type DoneMsg
    = ClickDone Subject
    | DoneResult (Result Http.Error String)
    | DoneChangeDescription String
    | DoneChangeWhatToDoNext String
    | SubmitDone
    | CancelDone


type alias State =
    { subjects : List ( Int, Subject )
    , openedIndex : Maybe Int
    , loading : Bool
    , toasterMsg : String
    , tiredMode : Bool
    , apiEndpoint : String
    , doneSubjectName : String
    , doneDescription : String
    , doneWhatToDoNext : String
    , addSubjectModal : Bool
    , newComplexity : Int
    , newPriority : Int
    , newSubjectName : String
    }


type alias Loading r =
    { r
        | loading : Bool
    }


type alias Flags =
    { apiEndpoint : String }



-- update


update : Msg -> State -> ( State, Cmd Msg )
update msg model =
    case msg of
        MySubjectMsg a ->
            updateSubject a model

        NewList (Ok subjects) ->
            ( { model | subjects = Array.toIndexedList subjects } |> disableLoading, Cmd.none )

        NewList (Err msg) ->
            errorResult model msg

        None ->
            ( model, Cmd.none )

        ToggleTiredMode ->
            ( { model | tiredMode = not model.tiredMode }, getListRequest model.apiEndpoint <| not model.tiredMode )

        ToggleAddSubjectModal ->
            ( { model | addSubjectModal = not model.addSubjectModal }, Cmd.none )

        ChangeNewComplexity complexity ->
            ( { model | newComplexity = complexity }, Cmd.none )

        ChangeNewPriority priority ->
            ( { model | newPriority = priority * 10 }, Cmd.none )

        ChangeNewSubjectName subjectName ->
            ( { model | newSubjectName = subjectName }, Cmd.none )

        SubmitNewSubject ->
            ( enableLoading model, Http.send NewSubjectResult <| Subject.addSubjectRequest model.apiEndpoint model )

        NewSubjectResult _ ->
            ( { model | addSubjectModal = False, newSubjectName = "" } |> unselectSubject, getListRequest model.apiEndpoint model.tiredMode )


updateSubject : SubjectMsg -> State -> ( State, Cmd Msg )
updateSubject msg model =
    case msg of
        ExpandSubjectClick ( indice, subject ) ->
            let
                detailCmd =
                    Http.send (MySubjectMsg << GetDetail) <| Subject.getDetail model.apiEndpoint subject

                newModel =
                    enableLoading model

                differentIndexFunc =
                    clickDifferentIndex newModel <| Just indice
            in
                case model.openedIndex of
                    Just indexVal ->
                        if indexVal == indice then
                            ( (clickedSameIndex newModel |> disableLoading), Cmd.none )
                        else
                            ( differentIndexFunc, detailCmd )

                    Nothing ->
                        ( differentIndexFunc, detailCmd )

        GetDetail (Ok subject) ->
            let
                newModel =
                    { model | subjects = replaceSubjectFromList model.subjects subject }
            in
                ( newModel |> disableLoading, Cmd.none )

        RemoveClick subject ->
            let
                removeHttp =
                    Http.send (MySubjectMsg << Remove) <| Subject.removeRequest model.apiEndpoint subject
            in
                ( model |> enableLoading, removeHttp )

        Remove (Ok _) ->
            ( model |> enableLoading, getListRequest model.apiEndpoint model.tiredMode )

        Remove (Err msg) ->
            errorResult model msg

        GetDetail (Err msg) ->
            errorResult
                model
                msg

        MyDoneMsg a ->
            updateDone a model


updateDone : DoneMsg -> State -> ( State, Cmd Msg )
updateDone msg model =
    case msg of
        DoneResult (Err msg) ->
            errorResult model msg

        ClickDone subject ->
            ( { model | doneSubjectName = subject.name }, Cmd.none )

        DoneChangeDescription description ->
            ( { model | doneDescription = description }, Cmd.none )

        DoneChangeWhatToDoNext next ->
            ( { model | doneWhatToDoNext = next }, Cmd.none )

        SubmitDone ->
            let
                doneHttp =
                    Http.send (MySubjectMsg << MyDoneMsg << DoneResult) <| Subject.doneRequest model.apiEndpoint model
            in
                ( model |> enableLoading |> resetCurrentDone, doneHttp )

        CancelDone ->
            ( model |> resetCurrentDone, Cmd.none )

        DoneResult (Ok _) ->
            ( disableLoading model |> unselectSubject, getListRequest model.apiEndpoint model.tiredMode )


unselectSubject model =
    { model | openedIndex = Nothing }


resetCurrentDone state =
    { state | doneSubjectName = "", doneDescription = "", doneWhatToDoNext = "" }


clickedSameIndex model =
    { model | openedIndex = Nothing }


clickDifferentIndex model index =
    { model | openedIndex = index }


disableLoading : Loading r -> Loading r
disableLoading model =
    { model | loading = False }


enableLoading : Loading r -> Loading r
enableLoading model =
    { model | loading = True }


getOffsetOfSubject : List ( Int, Subject ) -> Subject -> Int
getOffsetOfSubject subjects subject =
    let
        filtered =
            List.filter (\x -> subject.name == (Tuple.second x).name) subjects
    in
        case filtered of
            [ a ] ->
                Tuple.first a

            _ ->
                0


errorResult : State -> Error -> ( State, Cmd Msg )
errorResult model msg =
    ( { model | toasterMsg = (toString msg), loading = False }, Cmd.none )


replaceSubjectFromList : List ( Int, Subject ) -> Subject -> List ( Int, Subject )
replaceSubjectFromList list subject =
    (List.map (\x -> Subject.replaceSame subject x) list)



-- view


view : State -> Html.Styled.Html Msg
view state =
    div [ css [ color defaultColors.textNormal ] ]
        [ --header container
          div [ css [ displayFlex, justifyContent flexEnd ] ]
            [ div [ css [] ]
                [ a [ css [ padding (px 10) ], href "?page=log" ]
                    [ text "Complete History"
                    ]
                , a [ css [ margin (px 30) ], href "/" ] [ text "Logout" ]
                ]
            ]
        , --main content
          div
            [ css [ marginTop (px 50), marginLeft (px 10), marginRight (px 10) ] ]
            [ -- conditional loading, modals
              getLoadingHtml state.loading
            , doneModal state
            , addSubjectModal state.addSubjectModal
            , Toaster.html state.toasterMsg

            -- action menu container
            , div
                [ css [ displayFlex, margin (px 20) ] ]
                [ div [ css [ displayFlex, justifyContent spaceBetween, width (pct 100) ] ]
                    [ div []
                        [ input [ type_ "checkbox", onClick ToggleTiredMode ] []
                        , text " Tired mode"
                        ]
                    , button [ buttonCss, onClick ToggleAddSubjectModal ] [ text "Add Subject" ]
                    ]
                ]

            --subject list
            , div []
                [ subjectsToHtml state.openedIndex state.subjects
                ]
            ]
        ]


debugBorders css =
    let
        addWidth =
            borderWidth (px 1) :: css

        addStyle =
            borderStyle solid :: addWidth
    in
        addStyle


addSubjectModal isOpen =
    case isOpen of
        True ->
            div [ modalCss ]
                [ div []
                    [ h1 [] [ text "Add a subject" ]
                    , div [ css [ marginTop (px 10), marginBottom (px 10) ] ]
                        [ input [ inputCss, type_ "text", placeholder "Subject name", onInput ChangeNewSubjectName, Html.Styled.Attributes.required True ] []
                        , select [ selectCss, on "change" (Json.Decode.map ChangeNewPriority targetValueIntParse) ]
                            [ option [ Html.Styled.Attributes.value "0" ]
                                [ text "0 - No Priority" ]
                            , option [ Html.Styled.Attributes.value "1" ]
                                [ text "1 - Low Priority" ]
                            , option [ Html.Styled.Attributes.value "2" ]
                                [ text "2" ]
                            , option [ Html.Styled.Attributes.value "3" ]
                                [ text "3" ]
                            , option [ Html.Styled.Attributes.value "4" ]
                                [ text "4" ]
                            , option [ Html.Styled.Attributes.value "5" ]
                                [ text "5 - Medium Priority" ]
                            , option [ Html.Styled.Attributes.value "6" ]
                                [ text "6" ]
                            , option [ Html.Styled.Attributes.value "7" ]
                                [ text "7" ]
                            , option [ Html.Styled.Attributes.value "8" ]
                                [ text "8" ]
                            , option [ Html.Styled.Attributes.value "9" ]
                                [ text "9" ]
                            , option [ Html.Styled.Attributes.value "10" ]
                                [ text "10 - Higest priority" ]
                            ]
                        , select [ selectCss, on "change" (Json.Decode.map ChangeNewComplexity targetValueIntParse) ]
                            [ option [ Html.Styled.Attributes.value "10" ]
                                [ text "Easy" ]
                            , option
                                [ Html.Styled.Attributes.value "50", Html.Styled.Attributes.selected True ]
                                [ text "Medium" ]
                            , option
                                [ Html.Styled.Attributes.value "80" ]
                                [ text "Hard" ]
                            , option
                                [ Html.Styled.Attributes.value "100" ]
                                [ text "Hardest" ]
                            ]
                        ]
                    , button
                        [ buttonCss, onClick ToggleAddSubjectModal ]
                        [ text "Cancel" ]
                    , button
                        [ buttonCss, onClick SubmitNewSubject ]
                        [ text "Confirm" ]
                    ]
                ]

        False ->
            emptyNode


subjectsToHtml : Maybe Int -> List ( Int, Subject ) -> Html.Styled.Html Msg
subjectsToHtml openedIndex list =
    let
        innerList =
            List.map (subjectToHtml openedIndex) list
    in
        ul [ css [ listStyle none ] ] innerList


subjectToHtml : Maybe Int -> ( Int, Subject ) -> Html.Styled.Html Msg
subjectToHtml openedIndice ( indice, subject ) =
    li [ onClick ((MySubjectMsg << ExpandSubjectClick) ( indice, subject )), subjectCss openedIndice ( indice, subject ), id <| "subject_" ++ toString indice ]
        [ div []
            [ div [ css [ fontSize (Css.em 1.2) ] ]
                [ span [ css [ fontSize (Css.em 0.5), marginRight (px 15) ] ] [ text <| toString (indice + 1) ++ "." ]
                , h1 [ class "noselect", css [ display inline, color defaultColors.textHighlight, marginRight (px 20) ] ] [ text subject.name ]
                , maybePredicate openedIndice (\a -> a == indice) emptyNode <| inlineInfoOfSubject subject
                , (doneStart subject)
                ]
            , maybePredicate openedIndice (\a -> a == indice) (hiddenHtml subject) emptyNode
            ]
        ]


inlineInfoOfSubject subject =
    span [ css [ fontSize (Css.em 0.7) ] ] [ text <| " " ++ toString subject.daysSinceLast ++ " days ago" ]


hiddenHtml subject =
    div [ onWithOptions "click" { stopPropagation = True, preventDefault = False } (Json.Decode.succeed None) ]
        [ --properity container
          div [ css [ displayFlex ] ]
            [ div [ css [ displayFlex, justifyContent spaceBetween, width (pct 70), flexWrap wrap ] ]
                [ div []
                    [ subjectProperty "Priority" <| toString subject.priority
                    , subjectProperty "Complexity" <| toString subject.complexity
                    ]
                , div []
                    [ subjectProperty "Days since last session" <| toString subject.daysSinceLast
                    , subjectProperty "Hours already invested" <| subject.timeAlreadyInvested
                    ]
                ]
            ]
        , div
            []
            [ subjectProperty "Next Action" subject.whatToDoNext
            ]
        , div []
            [ h2 [ css [ textAlign center, marginTop (px 50), fontWeight bold ] ] [ text "History" ]
            , div [ css [ margin (px 30) ] ] (List.map studyEntryToHtml subject.history)
            ]
        , subjectButton "Remove" ((MySubjectMsg << RemoveClick) subject)
        ]


maybePredicate maybeValue predicate ifTrue ifFalse =
    case maybeValue of
        Just maybeValue ->
            if (predicate maybeValue) then
                ifTrue
            else
                ifFalse

        Nothing ->
            ifFalse


doneStart : Subject -> Html.Styled.Html Msg
doneStart subject =
    div [ css [ Css.float right ] ]
        [ subjectButton "Done" ((MySubjectMsg << MyDoneMsg << ClickDone) subject)
        ]


subjectProperty name value =
    p [ css [ margin (px 20) ] ]
        [ text <| name ++ ": " ++ value
        ]


doneModal : Subject.DoneData r -> Html Msg
doneModal doneInfo =
    case String.length doneInfo.doneSubjectName of
        0 ->
            emptyNode

        _ ->
            div [ modalCss ]
                [ div []
                    [ h1 [] [ text "Record session" ]
                    , input [ inputCss, type_ "text", placeholder "What was done?", onInput (MySubjectMsg << MyDoneMsg << DoneChangeDescription) ] []
                    , input [ inputCss, type_ "text", placeholder "What is to de done next?", onInput (MySubjectMsg << MyDoneMsg << DoneChangeWhatToDoNext) ] []
                    , div []
                        [ button [ onClick (MySubjectMsg << MyDoneMsg <| CancelDone) ] [ text "Cancel" ]
                        , button [ onClick (MySubjectMsg << MyDoneMsg <| SubmitDone) ] [ text "Confirm" ]
                        ]
                    ]
                ]


subjectButton : String -> Msg -> Html.Styled.Html Msg
subjectButton textStr msg =
    button [ buttonCss, onWithOptions "click" { stopPropagation = True, preventDefault = False } (Json.Decode.succeed msg) ]
        [ text textStr ]


inputCss : Attribute Msg
inputCss =
    css [ display block, width (px 300), margin (px 1), marginBottom (px 3), padding (px 10) ]


selectCss =
    css [ display block, width (px 300), marginBottom (px 3), padding (px 4) ]


buttonCss =
    css [ minWidth (px 60), margin (px 3), minHeight (px 30) ]


subjectCss selectedIndex ( index, subject ) =
    css
        [ borderRadius (px 10), display block, borderWidth (px 1), padding (px 20), marginBottom (px 1), backgroundColor (selectedColor selectedIndex ( index, subject )) ]


selectedColor selectedIndex ( index, subject ) =
    case selectedIndex of
        Just x ->
            if index == x then
                defaultColors.selectedBackground
            else
                defaultColors.normalBackground

        _ ->
            defaultColors.normalBackground


studyEntryToHtml : StudyEntry -> Html Msg
studyEntryToHtml studyEntry =
    li [ css [ minHeight (px 30) ] ]
        [ p [ css [ marginTop (px 15), color defaultColors.textHighlight ] ] [ text studyEntry.date ]
        , p [ css [ marginLeft (px 20) ] ] [ text <| studyEntry.description ]
        ]


getLoadingHtml enabled =
    case enabled of
        True ->
            div [ css [ justifyContent center, alignItems center, position fixed, displayFlex, top (px 0), left (px 0), width (pct 100), height (pct 100), backgroundColor <| rgba 255 255 255 0.9 ] ]
                [ text "Loading"
                ]

        False ->
            emptyNode


modalCss =
    css [ justifyContent center, alignItems center, position fixed, displayFlex, top (px 0), left (px 0), width (pct 100), height (pct 100), backgroundColor <| rgba 255 255 255 1 ]


emptyNode =
    text ""


subscriptions : State -> Sub Msg
subscriptions model =
    Sub.none



-- requests


getListRequest : String -> Bool -> Cmd Msg
getListRequest endpoint tiredMode =
    let
        url =
            "https://" ++ endpoint ++ "/scheduler" ++ (tiredMode |> toUrlBool)

        request =
            Http.request
                { method = "GET"
                , headers = [ Http.header "Content-Type" "application/json" ]
                , url = url
                , body = Http.emptyBody
                , expect = (Http.expectJson decodeSubjectList)
                , timeout = Nothing
                , withCredentials = True
                }
    in
        Http.send NewList request


toUrlBool : Bool -> String
toUrlBool bool =
    case bool of
        True ->
            "?tiredMode=True"

        False ->
            ""



-- decoders


decodeSubjectList : Decoder (Array Subject)
decodeSubjectList =
    Json.Decode.array Subject.decodeSubject


decodeEmptyResult =
    Json.Decode.succeed ""
