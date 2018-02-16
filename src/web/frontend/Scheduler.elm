module Scheduler exposing (..)

--view imports

import Html
import Html.Styled
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, placeholder, type_, id)
import Html.Styled.Events exposing (..)
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


main =
    Html.programWithFlags { init = init, view = view >> Html.Styled.toUnstyled, update = update, subscriptions = subscriptions }


init : Flags -> ( State, Cmd Msg )
init flags =
    ( State [] Nothing True "" False flags.apiEndpoint "" "" "", getListRequest flags.apiEndpoint False )



-- Model


type Msg
    = NewList (Result Http.Error (Array Subject))
    | ToggleTiredMode
    | None
    | MySubjectMsg SubjectMsg


type SubjectMsg
    = ExpandSubjectClick ( Int, Subject )
    | Remove (Result Http.Error String)
    | RemoveClick Subject
    | GetDetail (Result Http.Error Subject)
    | MyDoneMsg DoneMsg


type DoneMsg
    = ClickDone Subject
    | CancelDone Subject
    | DoneResult (Result Http.Error String)
    | DoneChangeDescription String
    | DoneChangeWhatToDoNext String
    | SubmitDone Subject


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
    }


type alias Loading r =
    { r
        | loading : Bool
    }


type alias Subject =
    { name : String
    , daysSinceLast : Int
    , timeAlreadyInvested : String
    , history : List StudyEntry
    , whatToDoNext : String
    , complexity : Int
    , priority : Int
    }


type alias DoneData r =
    { r
        | doneSubjectName : String
        , doneDescription : String
        , doneWhatToDoNext : String
    }


type alias StudyEntry =
    { date : String
    , description : String
    , subjectName : String
    }


emptySubject : Subject
emptySubject =
    Subject "" 0 "" [] "" 0 0


type alias Flags =
    { apiEndpoint : String }



-- update


update : Msg -> State -> ( State, Cmd Msg )
update msg model =
    case msg of
        NewList (Ok subjects) ->
            ( { model | subjects = Array.toIndexedList subjects, loading = False }, Cmd.none )

        MySubjectMsg a ->
            updateSubject a model

        NewList (Err msg) ->
            errorResult model msg

        None ->
            ( model, Cmd.none )

        ToggleTiredMode ->
            ( { model | tiredMode = not model.tiredMode }, getListRequest model.apiEndpoint <| not model.tiredMode )


updateSubject : SubjectMsg -> State -> ( State, Cmd Msg )
updateSubject msg model =
    case msg of
        ExpandSubjectClick ( indice, subject ) ->
            let
                detailCmd =
                    getDetail model.apiEndpoint subject

                newModel =
                    enableLoading model

                differentIndexFunc =
                    setCurrentDoneSubject (clickDifferentIndex newModel <| Just indice) subject.name
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
            ( model |> enableLoading, removeRequest model.apiEndpoint subject )

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
            ( model, Cmd.none )

        CancelDone subject ->
            ( model, Cmd.none )

        DoneChangeDescription description ->
            ( { model | doneDescription = description }, Cmd.none )

        DoneChangeWhatToDoNext next ->
            ( { model | doneWhatToDoNext = next }, Cmd.none )

        SubmitDone subject ->
            ( model |> enableLoading, doneRequest model.apiEndpoint model )

        DoneResult (Ok _) ->
            ( { model | loading = False }, getListRequest model.apiEndpoint model.tiredMode )


setCurrentDoneSubject : DoneData r -> String -> DoneData r
setCurrentDoneSubject doneData name =
    { doneData | doneSubjectName = name }


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
    (List.map (\x -> replaceSame subject x) list)


replaceSame : Subject -> ( Int, Subject ) -> ( Int, Subject )
replaceSame new ( indice, orig ) =
    case orig.name == new.name of
        True ->
            ( indice, new )

        False ->
            ( indice, orig )


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


removeRequest : String -> Subject -> Cmd Msg
removeRequest endpoint subject =
    let
        url =
            "https://" ++ endpoint ++ "/rm/" ++ subject.name

        request =
            Http.request
                { method = "GET"
                , headers = [ Http.header "Content-Type" "application/json" ]
                , url = url
                , body = Http.emptyBody
                , expect = (Http.expectJson decodeEmptyResult)
                , timeout = Nothing
                , withCredentials = True
                }
    in
        Http.send (MySubjectMsg << Remove) request


getDetail : String -> Subject -> Cmd Msg
getDetail endpoint subject =
    let
        url =
            "https://" ++ endpoint ++ "/detail/" ++ subject.name

        request =
            Http.request
                { method = "GET"
                , headers = [ Http.header "Content-Type" "application/json" ]
                , url = url
                , body = Http.emptyBody
                , expect = (Http.expectJson decodeSubject)
                , timeout = Nothing
                , withCredentials = True
                }
    in
        Http.send (MySubjectMsg << GetDetail) request


doneRequest : String -> DoneData r -> Cmd Msg
doneRequest endpoint doneData =
    let
        url =
            "https://" ++ endpoint ++ "/done/" ++ doneData.doneSubjectName

        body =
            Json.Encode.object
                [ ( "description", Json.Encode.string doneData.doneDescription )
                , ( "whatToDoNext", Json.Encode.string doneData.doneWhatToDoNext )
                ]

        request =
            Http.request
                { method = "POST"
                , headers = [ Http.header "Content-Type" "application/json" ]
                , url = url
                , body = (Http.jsonBody body)
                , expect = (Http.expectJson decodeEmptyResult)
                , timeout = Nothing
                , withCredentials = True
                }
    in
        Http.send (MySubjectMsg << MyDoneMsg << DoneResult) request



-- decoders


decodeSubjectList : Decoder (Array Subject)
decodeSubjectList =
    Json.Decode.array decodeSubject


decodeSubject : Decoder Subject
decodeSubject =
    Json.Decode.Pipeline.decode Subject
        |> Json.Decode.Pipeline.required "name" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "days_since_last_study" (Json.Decode.int)
        |> Json.Decode.Pipeline.required "time_already_invested_str" (Json.Decode.string)
        |> Json.Decode.Pipeline.optional "history" (Json.Decode.list decodeStudyEntry) []
        |> Json.Decode.Pipeline.required "what_to_do_next" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "complexity" (Json.Decode.int)
        |> Json.Decode.Pipeline.required "priority" (Json.Decode.int)


decodeSubjectHistory =
    at [ "history" ] (Json.Decode.array decodeStudyEntry)


decodeStudyEntry =
    Json.Decode.Pipeline.decode StudyEntry
        |> Json.Decode.Pipeline.required "date" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "description" (Json.Decode.string)
        |> Json.Decode.Pipeline.required "subject" (Json.Decode.string)


decodeEmptyResult =
    Json.Decode.succeed ""



-- view


view : State -> Html.Styled.Html Msg
view state =
    let
        loadingHtml =
            getLoadingHtml state.loading
    in
        div [ css [ color defaultColors.textNormal, top (px 0), left (px 0), margin (px 0), height (pct 100) ] ]
            [ loadingHtml
            , div [ css [ margin (pct 3) ] ]
                [ div []
                    [ input [ type_ "checkbox", onClick ToggleTiredMode ] []
                    , text "Tired mode"
                    ]
                , a [ css [ padding (px 10) ], href "index.html?page=log" ]
                    [ text "Log"
                    ]
                , a [ css [ padding (px 10) ], href "index.html?page=add" ]
                    [ text "Add"
                    ]
                , Toaster.html state.toasterMsg
                , div
                    []
                    [ subjectsToHtml state.openedIndex state.subjects
                    ]
                ]
            ]


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
                [ span [ css [ color defaultColors.textHighlight ] ] [ text subject.name ]
                , text
                    (" " ++ (subject.daysSinceLast |> toString) ++ " days ago -  " ++ (subject.timeAlreadyInvested))
                , (doneControlButtons subject)
                ]
            , (hiddenSubjectHtml openedIndice ( indice, subject ))
            ]
        ]


hiddenSubjectHtml : Maybe Int -> ( Int, Subject ) -> Html.Styled.Html Msg
hiddenSubjectHtml openedIndice ( indice, subject ) =
    case openedIndice of
        Just openedIndiceValue ->
            if openedIndiceValue == indice then
                div [ onWithOptions "click" { stopPropagation = True, preventDefault = False } (Json.Decode.succeed None) ]
                    [ div []
                        [ (doneFormForSubject subject)
                        , div []
                            [ p []
                                [ text <| "Priority: " ++ (toString subject.priority)
                                ]
                            , p []
                                [ text <| "Complexity: " ++ (toString subject.complexity)
                                ]
                            ]
                        , div [ css [ fontSize (Css.em 1.1) ] ]
                            [ text <| "What to do next: " ++ subject.whatToDoNext
                            ]
                        ]
                    , div []
                        [ text "History"
                        , div [] (List.map studyEntryToHtml subject.history)
                        ]
                    , subjectButton "Remove" ((MySubjectMsg << RemoveClick) subject)
                    ]
            else
                emptyNode

        Nothing ->
            emptyNode


doneControlButtons : Subject -> Html.Styled.Html Msg
doneControlButtons subject =
    div [ css [ Css.float right ] ]
        [ subjectButton "Cancel" ((MySubjectMsg << MyDoneMsg << CancelDone) subject)
        , subjectButton "Confirm" ((MySubjectMsg << MyDoneMsg << SubmitDone) subject)
        ]


doneFormForSubject subject =
    div [ css [ paddingTop (px 10) ] ]
        [ input [ inputCss, type_ "text", placeholder "What was done?", onInput (MySubjectMsg << MyDoneMsg << DoneChangeDescription) ] []
        , input [ inputCss, type_ "text", placeholder "What is to de done next?", onInput (MySubjectMsg << MyDoneMsg << DoneChangeWhatToDoNext) ] []
        ]


subjectButton : String -> Msg -> Html.Styled.Html Msg
subjectButton textStr msg =
    button [ onWithOptions "click" { stopPropagation = True, preventDefault = False } (Json.Decode.succeed msg) ]
        [ text textStr ]


inputCss : Attribute Msg
inputCss =
    css [ display block, width (px 300), margin (px 5), padding (px 10) ]


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
    li []
        [ p [ css [ color defaultColors.textHighlight ] ] [ text studyEntry.date ]
        , p [] [ text <| "  " ++ studyEntry.description ]
        ]


getLoadingHtml enabled =
    case enabled of
        True ->
            div [ css [ justifyContent center, alignItems center, position fixed, displayFlex, top (px 0), left (px 0), width (pct 100), height (pct 100), backgroundColor <| rgba 255 255 255 0.9 ] ]
                [ text "Loading"
                ]

        False ->
            emptyNode


emptyNode =
    text ""
