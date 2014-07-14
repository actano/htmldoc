define({ api: [
  {
    "type": "get",
    "url": "/api/planning-objects/",
    "title": "Request all top-level planning objects",
    "name": "GetAllPlanningObjects",
    "group": "PlanningObjects",
    "success": {
      "fields": {
        "Success - 200": [
          {
            "group": "Success - 200",
            "type": "PlanningObject[]",
            "field": "rows",
            "optional": false,
            "description": "Array of all top-level planning-objects"
          },
          {
            "group": "Success - 200",
            "type": "Number",
            "field": "rows.taskId",
            "optional": false,
            "description": "Id of the given planning object"
          },
          {
            "group": "Success - 200",
            "type": "Number",
            "field": "rows.position",
            "optional": false,
            "description": "position of planning object in hierarchy"
          }
        ]
      },
      "examples": [
        {
          "title": "Success-Response:",
          "content": "  HTTP/1.1 200 OK\n  {\n    \"rows\": [\n          {\n              \"taskId\": 1573111,\n              \"position\": 1,\n              \"owner\": \"user_classic_RP_USER_0\",\n              \"finish\": \"2014-03-25\",\n              \"name\": \"Kuchen backen\",\n              \"start\": \"2013-07-18\",\n              \"type\": \"summary\",\n              \"parent\": \"ROOT\",\n              \"numChildren\": 8,\n              \"id\": \"summary_classic_RP_PLANENTRY_3541\",\n              \"cas\": {\n                  \"0\": 3875667968,\n                  \"1\": 662029034\n              }\n          }\n      ]\n  }\n"
        }
      ]
    },
    "error": {
      "fields": {
        "Error 4xx": [
          {
            "group": "Error 4xx",
            "field": "InternalServerError",
            "optional": false,
            "description": "An internal server error occured."
          }
        ]
      },
      "examples": [
        {
          "title": "Error-Response:",
          "content": "  HTTP/1.1 500 Internal Server Error\n  {\n      \"err\": {\n          \"message\": \"Internal server error.\",\n      }\n  }\n"
        }
      ]
    },
    "version": "0.0.0",
    "filename": "/opt/actano-rplan/lib/planning-objects/server.coffee"
  },
  {
    "type": "get",
    "url": "/api/planning-objects/:id",
    "title": "Request a planning object",
    "name": "GetPlanningObject",
    "group": "PlanningObjects",
    "parameter": {
      "fields": {
        "Parameter": [
          {
            "group": "Parameter",
            "type": "Number",
            "field": "id",
            "optional": false,
            "description": "the requested object's unique id."
          }
        ]
      }
    },
    "success": {
      "examples": [
        {
          "title": "Success-Response:",
          "content": "  HTTP/1.1 200 OK\n  {\n      {\n          \"type\": \"task\",\n          \"name\": \"Vorgang 42\",\n          \"start\": \"2014-07-07T22:00:00.000Z\",\n          \"duration\": 23,\n          \"position\": 13,\n          \"parent\": \"ROOT\",\n          \"numChildren\": 0,\n          \"id\": \"8fb269a0-dfb2-4bce-997c-4a8995c52283\",\n          \"cas\": {\n              \"0\": 196608,\n              \"1\": 2581143397\n          }\n      }\n  }\n"
        }
      ],
      "fields": {
        "Success - 200": [
          {
            "group": "Success - 200",
            "type": "Number",
            "field": "taskId",
            "optional": false,
            "description": "Id of the given planning object"
          },
          {
            "group": "Success - 200",
            "type": "Number",
            "field": "position",
            "optional": false,
            "description": "position of planning object in hierarchy"
          },
          {
            "group": "Success - 200",
            "type": "etc",
            "field": "etc",
            "optional": false,
            "description": "etc"
          }
        ]
      }
    },
    "error": {
      "fields": {
        "Error 4xx": [
          {
            "group": "Error 4xx",
            "field": "InternalServerError",
            "optional": false,
            "description": "An internal server error occured."
          }
        ]
      },
      "examples": [
        {
          "title": "Error-Response:",
          "content": "  HTTP/1.1 500 Internal Server Error\n  {\n      \"err\": {\n          \"message\": \"Internal server error.\",\n      }\n  }\n"
        }
      ]
    },
    "version": "0.0.0",
    "filename": "/opt/actano-rplan/lib/planning-objects/server.coffee"
  },
  {
    "success": {
      "fields": {
        "Success - 200": [
          {
            "group": "Success - 200",
            "type": "Number",
            "field": "taskId",
            "optional": false,
            "description": "Id of the given planning object"
          },
          {
            "group": "Success - 200",
            "type": "Number",
            "field": "position",
            "optional": false,
            "description": "position of planning object in hierarchy"
          },
          {
            "group": "Success - 200",
            "type": "etc",
            "field": "etc",
            "optional": false,
            "description": "etc"
          }
        ]
      }
    },
    "group": "server.coffee",
    "type": "",
    "url": "",
    "version": "0.0.0",
    "filename": "/opt/actano-rplan/lib/planning-objects/server.coffee"
  }
] });
