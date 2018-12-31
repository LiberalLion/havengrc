module Authentication exposing
    ( Model
    , Msg(..)
    , getReturnHeaders
    , handleAuthResult
    , init
    , isLoggedIn
    , tryGetAuthHeader
    , tryGetUserProfile
    , update
    )

import Http
import Keycloak
import Ports as Ports exposing (saveSurveyState)


type alias Model =
    { state : Keycloak.AuthenticationState
    , lastError : Maybe Keycloak.AuthenticationError
    , logIn : Keycloak.Options -> Cmd Msg
    , logOut : () -> Cmd Msg
    }


init : (Keycloak.Options -> Cmd Msg) -> (() -> Cmd Msg) -> Maybe Keycloak.LoggedInUser -> Model
init logIn logOut initialUser =
    { state =
        case initialUser of
            Just user ->
                Keycloak.LoggedIn user

            Nothing ->
                Keycloak.LoggedOut
    , lastError = Nothing
    , logIn = logIn
    , logOut = logOut
    }


type Msg
    = AuthenticationResult Keycloak.AuthenticationResult
    | ShowLogIn
    | LogOut


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AuthenticationResult result ->
            let
                ( newState, error ) =
                    case result of
                        Ok user ->
                            ( Keycloak.LoggedIn user, Nothing )

                        Err err ->
                            ( Keycloak.LoggedOut, Just err )
            in
            ( { model | state = newState, lastError = error }, Cmd.none )

        ShowLogIn ->
            ( model, model.logIn Keycloak.defaultOpts )

        LogOut ->
            ( { model | state = Keycloak.LoggedOut }, Cmd.batch [ model.logOut (), Ports.saveSurveyState Nothing ] )


handleAuthResult : Keycloak.RawAuthenticationResult -> Msg
handleAuthResult =
    Keycloak.mapResult >> AuthenticationResult


tryGetUserProfile : Model -> Maybe Keycloak.UserProfile
tryGetUserProfile model =
    case model.state of
        Keycloak.LoggedIn user ->
            Just user.profile

        Keycloak.LoggedOut ->
            Nothing


isLoggedIn : Model -> Bool
isLoggedIn model =
    case model.state of
        Keycloak.LoggedIn _ ->
            True

        Keycloak.LoggedOut ->
            False


tryGetAuthHeader : Model -> List Http.Header
tryGetAuthHeader authModel =
    case authModel.state of
        Keycloak.LoggedIn user ->
            [ Http.header "Authorization" ("Bearer " ++ user.token) ]

        Keycloak.LoggedOut ->
            []


getReturnHeaders : List Http.Header
getReturnHeaders =
    [ Http.header "Prefer" "return=representation" ]
