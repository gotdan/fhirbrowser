fs   = require 'fs'
path = require 'path'

parseFeed = (feedJson, nest, topOnly) ->
	types = {}
	for entry in feedJson.feed.entry
		structure = entry.content.structure?[0]
		continue unless structure

		typeElements = parseType(structure)
		type = typeToTree(typeElements)
		if topOnly then delete type.children
		types[type.name] = type
	
	types = nestTypes(types) if nest
	return types


parseType = (structure) ->
	elements = []

	for element, i in structure.element
		pathParts = element.path.split('.')
		name = pathParts.pop()
		#special handler for extended types
		if i is 0 and structure.name
			name = structure.name
		#remove multitype designation
		if name.substr(name.length-3) is '[x]'
			name = name.substr(0, name.length-3)
		parent = pathParts.join('.')
		type = if element.definition?.type?.length is 1
			element.definition.type[0].code
		else if element.definition?.type
			"multitype"

		reference = if type and element.definition.type[0].profile
			element.definition.type[0].profile.split('/').pop()

		elements.push cleanElement =
			name: name
			path: element.path
			parent: parent
			short: element.definition.short
			formal: element.definition.formal
			min: element.definition.min
			max: element.definition.max
			synonym: element.definition.synonym
			constraint: element.definition.constraint
			binding: element.definition.binding
			type: type || 'none'
			reference: reference 

		if cleanElement.type is "multitype"
			_expandMultitype(cleanElement, element.definition.type, elements)

	return elements


_expandMultitype = (element, types, elements) ->
	for type in types
		reference = if type.profile
			type.profile.split('/').pop()
		name = reference || element.name + 
			type.code.charAt(0).toUpperCase() + type.code.slice(1)
		
		elements.push
			name: name
			parent: element.path
			path: "#{element.path}.#{name}"
			short: element.short
			formal: element.formal
			min: 0
			max: "1"
			type: type.code
			reference: reference

	return	elements

typeToTree = (elements) ->
	primitiveTypes = [
		"boolean","integer","decimal","base64Binary","instant",
		"string","uri","date","dateTime","code","oid","uuid","id",
		"xhtml"
	]
	_embedChildren = (element) ->
		for child in elements
			if child.parent is element.path
				if child.type is 'Extension'
					element.extendable = true
					continue
				element.children ||= []
				element.children.push child
				_embedChildren(child)

		if element.type in primitiveTypes or element.name is "contained"
			element.leaf = true
		return element

	return _embedChildren(elements[0])


nestTypes = (types) ->
	_embedChildren = (type) ->
		return type unless type.children
		for child in type.children
			_embedChildren(child)
			if child.type and types[child.type]
				for typeChild in types[child.type].children
					child.children ||= []
					child.children.push typeChild
					delete child.leaf
		return child	

	_embedChildren(v) for k, v of types
	return types

flattenType = (types, targetType) ->
	elements = []
	getElements = (element, path="", skipInPath) ->
		#skip direct children on multitype resource reference field
		skipInPath = skipInPath || element.type is "multitype" and 
			element.children[0].type isnt 'ResourceReference'

		skipChildInPath = element.type is "multitype" and 
			element.children[0].type is 'ResourceReference'

		unless skipInPath
			path = path + (if path.length then "." else "") + 
				element.name + (if element.max is "*" then "[]" else "")

		if element.children
			getElements(child, path, skipChildInPath) for child in element.children
		else if types[element.type]
			type = types[element.type]
			getElements(child, path) for child in type.children
		else
			elements.push path
	
	getElements types[targetType]		
	return elements

outputDir = "../dist/data"
flatDir = "../jsonpaths/"

#create initial tree
feed   = JSON.parse fs.readFileSync("profiles-resources.json", 'utf8')
groups = JSON.parse fs.readFileSync("groups.json", "utf8")

topResources = parseFeed feed, false, true
topLevelChildren = []
for k, v of groups
	children = (topResources[type] for type in v)
	topLevelChildren.push {name: k, children: children}

console.log "Writing Tree Root"
fs.writeFileSync path.join(outputDir, "root.json"),
	JSON.stringify {children: topLevelChildren, success: true}, null, "\t"

#build complex type json files
feed  = JSON.parse fs.readFileSync("profiles-types.json", 'utf8')
types = parseFeed feed, true
for k, v of types
	console.log "Writing Type: #{k}"
	fs.writeFileSync path.join(outputDir, "#{k}.json"),
		JSON.stringify { children: v.children, success: true}, null, "\t"

#build resource json files
feed = JSON.parse fs.readFileSync("profiles-resources.json", 'utf8')
resources = parseFeed feed
for k, v of resources
	console.log "Writing Resource: #{k}"
	fs.writeFileSync path.join(outputDir, "#{k}.json"),
		JSON.stringify { children: v.children, success: true}, null, "\t"

#combine all types and build flat definitions
combined = {}
combined[k] = v for k, v of resources
combined[k] = v for k, v of types

#build resource json files
for k, v of resources
	console.log "Writing Paths: #{k}"
	fs.writeFileSync path.join(flatDir, "#{k}.txt"),
		flattenType(combined, k).join("\n")
