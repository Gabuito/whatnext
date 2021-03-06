module Menu exposing (..)

import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, placeholder, type_, id, class, value, required, defaultValue)
import Html.Styled.Events exposing (..)
import Html.Events.Extra exposing (targetValueIntParse)
import Dom.Scroll
import Toaster exposing (..)
import Css exposing (..)
import Subject exposing (Subject, StudyEntry, DoneData)
import View exposing (defaultColors)
import DOM


type alias MenuState r =
    { r
        | sideMenu : Bool
    }


toggle menuState =
    { menuState | sideMenu = not menuState.sideMenu }


topBarHtml toggleMenuEvent elements =
    div
        [ css
            [ backgroundColor defaultColors.barColor
            , displayFlex
            , justifyContent spaceBetween
            , flexDirection row
            , minHeight (px 50)
            ]
        ]
        [ img
            [ css
                [ paddingLeft (px 3)
                , maxHeight (px 55)
                ]
            , src "images/expandMenu.png"
            , onClick toggleMenuEvent
            ]
            []
        , div [ css [ displayFlex, justifyContent flexEnd, alignItems center ] ]
            elements
        ]


sideBarHtmlOptional state configuredSidebar =
    View.inlineIf (state.sideMenu) (configuredSidebar) View.emptyNode


sideBarHtml toggleMenuEvent optionalItems =
    div
        [ css
            [ width (px 250)
            , position absolute
            ]
        ]
        [ div
            [ css
                [ displayFlex
                , flexDirection column
                ]
            , onClick toggleMenuEvent
            ]
            [ button [ css <| List.append View.buttonCss [ textAlign left ] ]
                [ text "Close menu" ]
            , optionalItems
            , a
                [ css
                    <|
                    List.append

                    [ zIndex (Css.int 333)]
                    <|
                    (View.buttonCss
                        |> View.overrideBackgroundColor
                            defaultColors.fail
                    )
                , href "/"
                ]
                [ text "Quit" ]
            ]
        ]
