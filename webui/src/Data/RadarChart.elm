module Data.RadarChart exposing (RadarChartConfig, generateIpsativeChart)

import Color exposing (Color, rgb, rgba, toRgba)
import Data.SurveyResponses exposing (AvailableResponse, AvailableResponseDatum)
import List.Extra exposing (getAt, groupWhile, unique)
import Utils exposing (smashList)


colors : List Color
colors =
    [ rgb 255 99 132
    , rgb 54 162 235
    , rgb 255 159 64
    , rgb 255 205 86
    , rgb 75 192 192
    , rgb 153 102 255
    , rgb 201 203 207
    ]


type alias RadarChartDataSet =
    { label : String
    , backgroundColor : String
    , borderColor : String
    , pointBackgroundColor : String
    , data : List Int
    }


type alias RadarChartData =
    { labels : List String
    , datasets : List RadarChartDataSet
    }


type alias LegendOptions =
    { position : String
    }


type alias TitleOptions =
    { display : Bool
    , text : String
    }


type alias ScaleOptions =
    { ticks : TickOptions
    }


type alias TickOptions =
    { beginAtZero : Bool
    }


type alias RadarChartOptions =
    { legend : LegendOptions
    , title : TitleOptions
    , scale : ScaleOptions
    }


type alias RadarChartConfig =
    { type_ : String
    , data : RadarChartData
    , options : RadarChartOptions
    }


{-| Converts a color to an css rgba string.
colorToCssRgba (rgba 255 0 0 0.5) -- "rgba(255, 0, 0, 0.5)"
-}
colorToCssRgba : Color -> String
colorToCssRgba cl =
    let
        { red, green, blue, alpha } =
            toRgba cl
    in
    cssColorString "rgba"
        [ String.fromFloat red
        , String.fromFloat green
        , String.fromFloat blue
        , String.fromFloat alpha
        ]


cssColorString : String -> List String -> String
cssColorString kind values =
    kind ++ "(" ++ String.join ", " values ++ ")"


generateIpsativeChart : AvailableResponse -> RadarChartConfig
generateIpsativeChart availableResponse =
    let
        radarChartData =
            { labels = getLabels availableResponse.data
            , datasets = getDataSets availableResponse.data
            }

        radarChartOptions =
            { legend = { position = "top" }
            , title =
                { display = True
                , text = availableResponse.name
                }
            , scale = { ticks = { beginAtZero = True } }
            }
    in
    { type_ = "radar"
    , data = radarChartData
    , options = radarChartOptions
    }


getLabels : List AvailableResponseDatum -> List String
getLabels data =
    data |> List.map .category |> List.sort |> unique


getDataSets : List AvailableResponseDatum -> List RadarChartDataSet
getDataSets points =
    let
        sortedByGroup =
            List.sortBy .group points

        nonEmptyListGroupedByGroup =
            groupWhile
                (\x y ->
                    x.group == y.group
                )
                sortedByGroup

        groupedByGroup =
            smashList nonEmptyListGroupedByGroup
    in
    List.map
        (\group ->
            let
                first =
                    List.head group

                groupNumber =
                    case first of
                        Just x ->
                            x.group

                        _ ->
                            0
            in
            { label = "Group " ++ String.fromInt groupNumber
            , backgroundColor = colorToCssRgba (makeTransparent (getAt (groupNumber - 1) colors |> Maybe.withDefault (rgb 0 0 0)))
            , borderColor = colorToCssRgba (getAt (groupNumber - 1) colors |> Maybe.withDefault (rgb 0 0 0))
            , pointBackgroundColor = colorToCssRgba (getAt (groupNumber - 1) colors |> Maybe.withDefault (rgb 0 0 0))
            , data = group |> List.sortBy .category |> List.map .points
            }
        )
        groupedByGroup


makeTransparent : Color -> Color
makeTransparent color =
    let
        colorObject =
            toRgba color
    in
    rgba colorObject.red colorObject.green colorObject.blue 0.2
