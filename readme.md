# FHIR Browser


### Demo: http://gotdan.github.io/fhirbrowser/


### Overview
FHIR Browser is a quick and dirty hierarchy and documentation browser for the [HL7 FHIR standard](http://hl7.org/implement/standards/fhir/) (DSTU Release 1.1). I've been playing around with mapping the data model of a commercial EHR to FHIR in my free time and wrote this last weekend to help me get a better handle on the FHIR structure.

You can access it [here](http://gotdan.github.io/fhirbrowser/index.html)


### Building the Code
FHIR Browser code consists of two components, a JSON pre-processing script written with [NodeJs](http://nodejs.org) in [CoffeeScript](http://coffeescript.org) and a web app that consumes the generated JSON written with [ExtJs](http://www.sencha.com/products/extjs/) in [CoffeeScript](http://coffeescript.org). The pre-processor is a bit of a hack to convert FHIR profiles into something easy for the client app to consume. Also, longer term, I may move the client app to a lighter weight web framework, but ExtJs has a nice tree control that made development quick (I don't have a lot of time to spend on this right now :).

**To compile the web app**

1. Install [NodeJs](http://nodejs.org)

2. Install coffeescript:

```npm install -g coffee-script```

3. Install the [Sencha Cmd Tools](http://www.sencha.com/products/sencha-cmd/download)

4. In the ```./app``` directory, compile the code:

```coffee -c -m -o . .```

5. In the ```./app``` directory, compile the ExtJs library:

```sencha -sdk ../dist/ext compile -classpath=./ exclude -all and include -recursive -file=app.js and concatenate -yui ../dist/app.js```


**To run the pre-processor**

1. Make sure NodeJs and CoffeeScript are installed (steps 1 and 2 above)

2. In the ```./script``` directory run:

```coffee index.coffee```


### License
The code is released under the GPLv3 license. Note that third party libraries may be under a different license.
