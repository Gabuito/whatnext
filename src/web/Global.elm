module Global exposing (..)

import Css exposing (..)
import Json.Decode
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (css, href, src, placeholder, type_)
import Html.Styled.Events exposing (..)


type alias Colors =
    { textHighlight : Css.Color
    , textNormal : Css.Color
    , selectedBackground : Css.Color
    , normalBackground : Css.Color
    }


defaultColors =
    Colors
        (Css.hex "b58900")
        (Css.hex "657b83")
        (Css.hex "fdf6e3")
        (Css.hex "ffffff")


decodeEmptyResult =
    Json.Decode.succeed ""



{-
   solarizedMainColor=#002b36
   solarized_base03=#002b36
   solarized_base02=#073642
   solarized_base01=#586e75
   solarized_base00=#657b83
   solarized_base0=#839496
   solarized_base1=#93a1a1
   solarized_base2=#eee8d5
   solarized_base3=#fdf6e3
   solarized_yellow=#b58900
   solarized_orange=#cb4b16
   solarized_red=#dc322f
   solarized_magenta=#d33682
   solarized_violet=#6c71c4
   solarized_blue=#268bd2
   solarized_cyan=#2aa198
   solarized_green=#859900
-}


getToasterHtml pageData =
    case String.length pageData.toasterMsg of
        0 ->
            div [] []

        _ ->
            div [ css [ borderStyle dashed, borderWidth (px 1), textAlign center ] ]
                [ text pageData.toasterMsg
                ]


inputCss =
    css [ display block, width (px 300), margin (px 5), padding (px 10) ]