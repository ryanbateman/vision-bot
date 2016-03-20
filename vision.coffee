# Description:
#   Query the Google Vision API from Hubot.
#
# Dependencies:
#   This script currently requires an s3 setup, an environment that supports Cairo/Cavnas (Heroku with the relevant multi-pack works)
#   and the following node packages: node-base64-image, canvas, node-gyp, aws-sdk. 
#
# Configuration:
#   AWS_ACCESS_KEY_ID               - AWS Access Key ID with S3 permissions
#   AWS_SECRET_ACCESS_KEY      - AWS Secret Access Key for ID
#   S3_REGION                                 - S3 region
#   AWS_BUCKET                             - Bucket to store temporary images for facial recognition
#
# Commands:
#   hubot vi/what's/the hell is <url> - Replies with a list of things it knows about the image
#   hubot text <url> - Replies with some text it OCR'ed from the image
#   hubot face <url> - Replies with some details about the faces it's detected in the image
#   hubot landmarks <url> - Replies with any landmarks it finds and a link to the location on Google Maps
#   hubot properties <url> - Replies with the dominant colours in an image
#
# Author:
#   Ryan Bateman (@rynbtmn)

base64 = require 'node-base64-image'
util  = require 'util'
Canvas = require 'canvas'

vision_key = process.env.VISION_API_KEY

aws   = require 'aws-sdk'
bucket = process.env.S3_BUCKET_NAME
aws.config.update
  accessKeyId:     process.env.AWS_ACCESS_KEY_ID
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
  region:          process.env.S3_REGION
s3 = new aws.S3()

#
# Listen for the queries related to the Vision API
#

module.exports = (robot) ->

  robot.respond /(vi|the hell is|what's|what is|whats) (.*)/i, (msg) ->
    msg.send "Okay, taking a look. Bear with me - this may take a few moments..."
    url = msg.match[2]
    type = "LABEL_DETECTION"
    response = setupCall(robot, msg, url, type)

  robot.respond /(landmark|landmarks) (.*)/i, (msg) ->
    msg.send "Okay, looking for landmarks. Bear with me - this may take a few moments..."
    url = msg.match[2]
    type = "LANDMARK_DETECTION"
    response = setupCall(robot, msg, url, type)    

  robot.respond /properties (.*)/i, (msg) ->
    msg.send "Okay, looking for image properties. Bear with me - this may take a few moments..."
    url = msg.match[1]
    type = "IMAGE_PROPERTIES"
    response = setupCall(robot, msg, url, type)    

  robot.respond /text (.*)/i, (msg) ->
    msg.send "Okay, looking for text. Bear with me - this may take a few moments..."
    url = msg.match[1]
    type = "TEXT_DETECTION"
    response = setupCall(robot, msg, url, type)    

  robot.respond /face (.*)/i, (msg) ->
    msg.send "Okay, looking for faces. Bear with me - this may take a few moments..."
    url = msg.match[1]
    type = "FACE_DETECTION"
    response = setupCall(robot, msg, url, type)    

#
# Make the call to the Vision API
#

setupCall = (robot, msg, url, type) ->
  options = { string: true }
  base64.base64encoder url, options, (err, image) ->
    if err
      console.log err
    else 
      requestJson = getJson(image, type)
      robot.http("https://vision.googleapis.com/v1/images:annotate?key=#{vision_key}")
        .header('Content-type', 'application/json')
        .post(JSON.stringify requestJson) (err, res, body) ->    
          jsonBody = JSON.parse body
          parseResponseAndDisplayData(msg, jsonBody, image)

#
# Check the response and format it for display to the user
#

parseResponseAndDisplayData = (msg, body, image) ->
  console.log JSON.stringify body
  responseText = ""
  apiResponse = body.responses[0]
  if Object.keys( apiResponse ).length == 0
    responseText += "Sorry, I couldn't find anything"
  if apiResponse.labelAnnotations?
    responseText += "Here's what I see: "
    for labelAnnotation, index in apiResponse.labelAnnotations
      responseText += "*#{labelAnnotation.description}* [" + Math.round(labelAnnotation.score * 100) + "%]"
      if index != apiResponse.labelAnnotations.length - 1
        responseText += ", "
  if apiResponse.imagePropertiesAnnotation?
    responseText += "\nDominant colours: "
    colors = apiResponse.imagePropertiesAnnotation.dominantColors.colors
    for dominantColor, index in colors
      rgb = [dominantColor.color.red, dominantColor.color.green, dominantColor.color.blue] 
      hexColour = hexify rgb
      responseText += "#{hexColour}"
      if index != colors.length - 1
        responseText += ", "
  if apiResponse.textAnnotations?
    responseText += "Here's the text I can make out: "
    responseText += "```"
    for textAnnotation in apiResponse.textAnnotations
      responseText += "" + textAnnotation.description  
    responseText += "```"
  if apiResponse.landmarkAnnotations?
    responseText += "Here are the landmarks I can make out: \n"
    for landmark, index in apiResponse.landmarkAnnotations
      if landmark.description
        responseText += "*#{landmark.description}* "
      else 
        responseText += "A place I think is here: "
      if landmark.locations
        responseText += "http://maps.google.com/maps?z=12&t=m&q=loc:#{landmark.locations[0].latLng.latitude}+#{landmark.locations[0].latLng.longitude}\n"  
  if apiResponse.faceAnnotations?
    responseText += "Here are some faces I can make out: \n"
    img = new Canvas.Image
    img.onload = ->
      canvas = new Canvas(img.width, img.height)
      context = canvas.getContext("2d")
      context.drawImage(img, 0, 0, img.width, img.height)
      for face, index in apiResponse.faceAnnotations
        drawFace face, index, context
        responseText += "Face #{index}\n\tJoy: #{face.joyLikelihood}\n\tSorrow: #{face.sorrowLikelihood}\n\tAnger: #{face.angerLikelihood}\n\tSurprise: #{face.surpriseLikelihood}\n\n"
      s3.upload { Key: Date.now() + ".jpg", Bucket: bucket, ACL: "public-read", Body: canvas.toBuffer()}, (err, output) ->
        if err
          msg.send "Seems there was an error detecting any faces"
        console.log "Location " + output.Location
        msg.send "Here's what they look like #{output.Location}"
    img.src = new Buffer image, "base64"
    console.log "setting source"
  msg.send responseText

#
# Draw the faces
#

drawFace = (face, index, context) ->
  poly = face.fdBoundingPoly.vertices
  context.lineWidth = 5
  context.strokeStyle = "rgba(255,0,0,1)"
  context.beginPath()
  context.lineTo(poly[0].x, poly[0].y)
  context.lineTo(poly[1].x, poly[1].y)
  context.lineTo(poly[2].x, poly[2].y)
  context.lineTo(poly[3].x, poly[3].y)
  context.lineTo(poly[0].x, poly[0].y)
  context.stroke()
  context.lineWidth = 1
  context.font = 'bold 50px Impact, serif'
  context.fillStyle = "#f00"
  context.fillText "#{index}", poly[3].x + 15, poly[3].y - 15
  context.strokeStyle = "#fff"
  context.strokeText "#{index}", poly[3].x + 15, poly[3].y - 15

#
# Hexify colours
#
hexify = (rgb) ->
    colour = '#'
    colour += pad Math.floor(rgb[0]).toString(16)
    colour += pad Math.floor(rgb[1]).toString(16)
    colour += pad Math.floor(rgb[2]).toString(16)
    colour

pad = (str) ->
  if str.length < 2 
    return "0" + str
  else
    return str

#
# Format some JSON for the Vision API call 
#

getJson = (image, type) ->
  return requestJson = {
        requests: [
          {
            image:
              content: image
            features: [ 
              {
                type: type
                maxResults: 10
              }
            ]
          }
        ]
      }