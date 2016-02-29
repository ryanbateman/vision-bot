# vision-bot
A Hubot script for query Google's Vision API using an image at some public URL and displaying the results.

### Requirements

At the moment this script requires a Google Vision API key, an S3 instance (to hold the results of facial detection), and, if you're using Heroku, an instance with a multiple-buildpack setup. In future, I'd prefer not to rely on S3. 

This was intended as a quick weekend project and has since turned into something with a few potentially interesting applications.  

#### Buildpacks

When running on Heroku, this script relies on [Cairo](http://cairographics.org/), a 2d graphics library that can added to Heroku with [this handy buildpack](https://github.com/mojodna/heroku-buildpack-cairo). You'll need to have this buildpack set up using Heroku's native [multi-buildpack](https://devcenter.heroku.com/articles/using-multiple-buildpacks-for-an-app) support. Running `heroku buildpacks` should show you the following buildpacks. 

```
1. https://github.com/mojodna/heroku-buildpack-cairo.git
2. https://github.com/heroku/heroku-buildpack-nodejs
```

### Commands


`whats`/`vi <url>` - Do a basic LABEL query, returning the top 10 results  
`text <url>` - Perform a TEXT query, returning all text found in the image  
`face <url>` - Perform a FACE query, returning all the faces found, an image showing where, and the Vision API's assessment of their emotions  
`properties <url>` - Perform a IMAGE_PROPERTIES query, returning the dominant colours in the image  
`landmark <url>` - Perform a LANDMARK query, returning the landmarks found in the image and Google Maps links to their locations  


#### whats
![what](https://github.com/ryanbateman/vision-bot/raw/master/examples/what.png)

#### text
![text](https://github.com/ryanbateman/vision-bot/raw/master/examples/text.png)

#### face
![face](https://github.com/ryanbateman/vision-bot/raw/master/examples/face.png)

#### properties
![colours](https://github.com/ryanbateman/vision-bot/raw/master/examples/colours.png)

#### landmark
![landmark](https://github.com/ryanbateman/vision-bot/raw/master/examples/landmarks.png)

### Notes

There's minimal error handling and my Coffeescript knowledge is basic, so there's a lot that can be improved. PRs welcomed.  

### Future updates

Assuming I do any further work on this, it'd be nice to add googly eyes to detected faces, support message attachments rather than URLs (for quick photo queries straight from Slack on your phone) and (as ever) a lot nicer error handling/sytax. 
