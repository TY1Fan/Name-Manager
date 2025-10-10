# Names Manager

## What it is?
Names manager is a 3-tier web application that allow users to add, list and delete names of people that they know.

## How it works?
The Frontend is exposed to the host (port 8080:80) and serves the HTML/JS files to the 
browser. Script.js makes API calls, then Nginx proxies these api calls to the backend service. 
The Backend runs inside its own container on port 8000 and exposes REST API endpoints 
under  /api/names. It handles input validation and communicates with the database. And 
responds  with  JSON  data  (list  of  names,  confirmation  of  added/deleted  name,  error 
messages).  
The  database  stores  all  data  and  persists  data  via  a  Docker volume. The backend container can reach the database container.

## How to run?
1. Run `docker compose up`
1. Search in browser `http://localhost:8080/`

## How to test?
1. Start up: Run the setup instructions above. The webapp should render.
1. Add a name: The added name should appear under `Recorded Names`.
1. List names: All available names should appear under `Recorded Names`, else it should display `Add names to view now.`.
1. Delete a name: Press `Delete` button for any recorded names. An alert should be displayed and on pressing `Ok`, the deleted name shall be removed.
1. Name validation: An alert will be shown for empty name, spacebar only, and names exceeding 50 characters.
1. Docker volume: Docker compose down without removing the volume, then docker compose up again. Previously added names should be present under the `Recorded Names`.