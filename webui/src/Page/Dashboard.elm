module Page.Dashboard exposing (Model, Msg(..), init, update, view)

import Html exposing (Html, br, button, div, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Ports


type Msg
    = ShowError String


type alias Model =
    { data : List Float
    }


init : Model
init =
    { data = [ 1, 1, 2, 3, 5, 8, 13 ]
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- TODO: this is a no-op and handled in Main.elm
        ShowError str ->
            ( model
            , Cmd.none
            )


view : Model -> Html Msg
view model =
    div
        []
        [ div [] [ text "This used to be the Centroid" ]
        , br [] []
        , button
            [ class "btn btn-secondary"
            , onClick (ShowError "this is an error message")
            ]
            [ text "Show Error" ]
        ]
