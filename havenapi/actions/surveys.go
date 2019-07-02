package actions

import (
	"encoding/json"
	"fmt"
	"bytes"
	"io/ioutil"
	"strings"
	"time"
	"github.com/gobuffalo/uuid"
	faktory "github.com/contribsys/faktory/client"
	"log"
	"github.com/getsentry/raven-go"
	"github.com/gobuffalo/buffalo"
	"github.com/gobuffalo/pop"

)

// rl is the rate limited to 5 requests per second.
// var rl = ratelimit.New(5)

// IpsativeResponse is a data type for the entered response
type IpsativeResponse struct {
	UUID             uuid.UUID   `json:"uuid" db:"uuid"`
	AnswerID         string      `json:"answer_id" db:"answer_id"`
	Category         string      `json:"category" db:"-"`
	GroupNumber      int         `json:"group_number" db:"group_number"`
	PointsAssigned   int         `json:"points_assigned" db:"points_assigned"`
	CreatedAt        time.Time   `json:"created_at" db:"created_at"`
	UserID           uuid.UUID   `json:"user_id" db:"user_id"`
	SurveyResponseID uuid.UUID   `json:"survey_response_id" db:"survey_response_id"`
	UserEmail        string      `json:"user_email" db:"user_email"`
}

// SurveyResult is a data type for the survey
type SurveyResult struct {
	AnswerID         string `json:"answer_id"`
	Category         string `json:"category"`
	GroupNumber      int    `json:"group_number"`
	PointsAssigned   int    `json:"points_assigned"`
}


// resultsStruct is a struct for the funnel
type resultsStruct struct {
	Results []SurveyResult `json:"survey_results"`
}

// SurveysHandler accepts json
func SurveysHandler(c buffalo.Context) error {
	rl.Take()

	request := c.Request()
	var results resultsStruct
	body, err := ioutil.ReadAll(request.Body)

	dec := json.NewDecoder(bytes.NewReader(body))
	if err := dec.Decode(&results); err != nil {
		return c.Error(400, fmt.Errorf("malformed post"))
	}

	if err != nil {
		raven.CaptureError(err, nil)
		return c.Error(500, err)
	}

	remoteAddress := strings.Split(request.RemoteAddr, ":")[0]
	surveyID, err := SaveSurveyResults(results.Results, c)
	if err != nil {
		raven.CaptureError(err, nil)

		return c.Error(
			500,
			fmt.Errorf(
				"Error inserting survey to database: %s for remote address %s",
				err.Error(),
				remoteAddress))
	}

	// Add job to the queue
	client, err := faktory.Open()
	if err != nil {
		raven.CaptureError(err, nil)

		return c.Error(500, err)
	}

	createSlideJob := faktory.NewJob("CreateSlide", surveyID, c.Value("email") )
	createSlideJob.ReserveFor = 60
	createSlideJob.Queue = "critical"
	err = client.Push(createSlideJob)
	if err != nil {
		raven.CaptureError(err, nil)

		return c.Error(500, err)
	}

	responses := []IpsativeResponse{}
	// To find the state the value of sub from the Middleware is used.
	tx := c.Value("tx").(*pop.Connection)
	err = tx.RawQuery("set local search_path to mappa, public").Exec()
	if err != nil {
		return c.Error(500, fmt.Errorf("Database error: %s", err.Error()))
	}
	query := tx.Where("survey_response_id = ($1)", surveyID )
	err = query.All(&responses)
	if err != nil {
		raven.CaptureError(err, nil)
		return c.Error(500, err)
	}

	return c.Render(200, r.JSON(responses))
}

// SaveSurveyResults creates a survey_response and saves all responses
func SaveSurveyResults(results []SurveyResult, c buffalo.Context) (string, error) {
	tx := c.Value("tx").(*pop.Connection)
	rows, err := tx.TX.Query("INSERT INTO mappa.survey_responses DEFAUlT VALUES RETURNING uuid;")
	if err != nil {
		return "", err
	}
	defer rows.Close()
	var surveyResponseID string
	for rows.Next() {
		var uuid string
		err = rows.Scan(&uuid)
		fmt.Println("Created new survey_response:", uuid)
		if err != nil {
			return "", err
		}
		surveyResponseID = uuid
	}

	if err := rows.Err(); err != nil {
		log.Fatal(err)
	}

	for _, result := range results {
		_, err = tx.TX.Exec(
			"INSERT INTO mappa.ipsative_responses (answer_id, group_number, points_assigned, survey_response_id) VALUES ($1, $2, $3, $4)",
			result.AnswerID,
			result.GroupNumber,
			result.PointsAssigned,
			surveyResponseID,
		)
		if err != nil {
			return "", err
		}
	}

	return surveyResponseID, err
}