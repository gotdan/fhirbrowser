Ext.define 'FhirBrowser.proxy.JsonAjax',
	extend: 'Ext.data.proxy.Ajax'
	alias: 'proxy.jsonajax'
	#noCache: false
	buildUrl: (request) ->
		node = request.operation.node
		nodeType = node.get('type') || 'root'

		if nodeType is "Resource"
			nodeType = request.operation.node.get('name')
		
		request.url = "#{request.proxy.url}/#{nodeType}.json"

		@callParent(arguments)


Ext.define 'FhirBrowser.model.FhirType',
	extend: 'Ext.data.Model'
	fields: [
		'leaf', 'short', 'formal', 'reference', 
		'extendable', 'type', 'name', 'path'
	,
		name: 'qtip', mapping: 'short'
	,
		name: 'count', convert: (v, record) ->
			return null unless record.raw.min isnt undefined
			"#{record.raw.min}..#{record.raw.max}"
	,
		name: 'valueset', convert: (v, record) ->
			text = record.raw?.binding?.name || null
			if record.raw?.binding?.conformance is 'required'
				text += " (required)"
			else if record.raw?.binding?.conformance is 'preferred'
				text += " (preferred)"
			else if record.raw?.binding?.conformance is 'example'
				text+= " (example)"
	,
		name: 'valuesetLink', convert: (v, record) ->
			record.raw?.binding?.referenceUri ||
				record.raw?.binding?.referenceResource?.reference
	,
		name: 'referenceLink', convert: (v, record) ->
			if record.raw.reference
				"http://www.hl7.org/implement/standards/fhir/" + record.raw.reference + ".html"
	,
		name: 'typeLink', convert: (v, record) ->
			base = "http://www.hl7.org/implement/standards/fhir/"
			if !record.raw.parent
				base + record.raw.name + ".html"
			else if record.raw.type is 'Resource'
				base + "references.html#contained"
			else if record.raw.type is 'ResourceReference'
				base + "references.html#ResourceReference"
			else if record.raw.type is "Narrative"
				base + "narrative.html"
			else if record.raw.type is "none"
				null 
			else if record.raw.type isnt 'multitype'
				base + "datatypes.html#" + record.raw.type
			else
				null
	]

Ext.define 'FhirBrowser.store.FhirTypeStore',
	requires: ['FhirBrowser.proxy.JsonAjax']
	extend: 'Ext.data.TreeStore'
	model: 'FhirBrowser.model.FhirType'
	autoLoad: true
	proxy:
		type: 'jsonajax'
		url: AppGlobals.dataPath


Ext.define 'FhirBrowser.view.TreeMenu',
	extend: 'Ext.menu.Menu'
	items: [
		text: 'Expand Resources'
	,
		text: 'Collapse All'
	,
		xtype: 'menuseparator'
	,
		text: 'About'
	]


Ext.define 'FhirBrowser.view.ResourceTree',
	extend: 'Ext.tree.Panel'
	xtype: 'resourcetree'
	useArrows: true
	title: "FHIR Resource Browser"
	store: 'FhirBrowser.store.FhirTypeStore'
	rootVisible: false
	tools: [ type: 'gear' ]	
	columns:
		items: [
			text: "Name"
			dataIndex: "name"
			xtype: "treecolumn"
			sortable: false
			hideable: false
			flex: 2
		,
			text: "Type"
			dataIndex: "type"
			flex: 1
			sortable: false
			renderer: (value, meta, record) ->
				if value is "multitype"
					"Choose One"
				else if (reference = record.get "reference") 				
					"Ref To: #{reference}"
				else 
					value
		,
			text: "Count"
			dataIndex: "count"
			sortable: false
			align: 'center'
		,
			text: "ValueSet"
			dataIndex: "valueset"
			sortable: false
			flex: 1

		]


Ext.define 'FhirBrowser.view.Viewport',
	extend: 'Ext.container.Viewport'
	requires:[
		'Ext.layout.container.Border'
		'FhirBrowser.view.ResourceTree',
		'FhirBrowser.view.TreeMenu'
	]
	layout: 'border'
	items: [
		title: 'FHIR Resource Browser'
		xtype: 'resourcetree'
		region: 'center'
		id: 'resource-tree'
		flex: 2
	,
		xtype: 'panel'
		region: 'south'
		title: 'Resource Detail'
		id: 'detail-panel' 
		split: true
		collapsible: true
		bodyPadding: "0 10 0 10"
		flex: 1
		tpl: [
			'<p><b>Type:</b> <tpl if="type === \'multitype\'">'
			'Choice | '
			'<tpl elseif="type === \'none\'">'
			'NA | '
			'<tpl else>'
			'<a href="{typeLink}" target="_blank">{type}</a> | '
			'</tpl>'
			'<tpl if="reference">'
			'<b>Target:</b> <a href="{referenceLink}" target="_blank">{reference}</a> (<a id="show-resource" href="#">Show</a>) | '
			'</tpl>'
			'<b>Count:</b> {count} | <b>Extendable:</b> '
			'<tpl if="extendable">Yes<tpl else>No</tpl>'
			'</p>'
			'<tpl if="valueset"><p><b>Value Set:</b> '
			'<a href="{valuesetLink}" target="_blank">{valueset}</a></p></tpl>'
			'<p><b>Short Description:</b><br />{short}</p>'
			'<p><b>Full Description:</b><br />{formal}</p>'
		]
		html: "<p>Select an item from the list to get started</p>"
	]

Ext.application
	name: 'FhirBrowser'
	requires: [
		'Ext.ComponentQuery'
	]
	views: [
		'FhirBrowser.view.Viewport'
	]
	models: [
		'FhirBrowser.model.FhirType'
	]
	stores: [
		'FhirBrowser.store.FhirTypeStore'
	]
	autoCreateViewport: true
	aboutTarget: 'https://github.com/gotdan/fhirbrowser/blob/master/readme.md'

	launch: ->
		@hideMask()	

		tree = Ext.getCmp('resource-tree')
		tree.on 'select', @onSelect, @

		treeMenu = Ext.create 'FhirBrowser.view.TreeMenu'
		treeMenu.on 'click', @onMenuItem, @

		tree.down('tool').on 'click', (gear) ->
			treeMenu.showBy(gear)

		panel = Ext.getCmp('detail-panel')
		panel.body.on 'click', (e) ->
			if e.target and e.target.id is 'show-resource'
				@jumpToReference()
		, @

	onMenuItem: (menu, item) ->
		tree = Ext.getCmp('resource-tree')		
		if item.text is 'Expand Resources'
			tree.getRootNode().expandChildren()
		else if item.text is 'Collapse All'
			tree.getRootNode().eachChild (node) ->
				node.collapse(true)
		else if item.text is 'About'
			window.open FhirBrowser.app.aboutTarget,'_blank'

	onSelect:(treepanel, record, index) ->
		return if record.getDepth() is 1
		currentNode = record
		path = []
		while currentNode.parentNode.parentNode
			skipInPath = (
				currentNode.get("type") is "multitype" and
				currentNode.getChildAt(0).get("type") isnt 'ResourceReference'
			) or (
				currentNode.parentNode.get("type") is "multitype" and
				currentNode.get("type") is 'ResourceReference'
			)
			unless skipInPath
				appendix = if currentNode.raw.max is '*' then "[]" else "" 
				path.unshift currentNode.get('name') + appendix
			currentNode = currentNode.parentNode
		path.push "+" unless record.get('leaf')
		panel = Ext.getCmp('detail-panel')
		panel.setTitle path.join('.')
		panel.update record.getData()

		# tree.on 'itemdblclick', (treepanel, record, item, index) ->
		# 	if console then console.log record.raw


	jumpToReference: ->
		tree = Ext.getCmp('resource-tree')
		if (currentNode = tree.getSelectionModel().getSelection()?[0]) and
			(ref = currentNode.get 'reference')
				refFinder = (node) ->
					return true if node.get('name') is ref and node.getDepth() is 2
				if target = tree.getRootNode().findChildBy refFinder, @, true
					target.expand()
					tree.getSelectionModel().select target


	hideMask: ->
		loadingMask = Ext.get('loading-mask')
		loading = Ext.get('loading')
		loading.fadeOut({ duration: 0.2, remove: true })
		loadingMask.fadeOut({ duration: 0.2, remove: true })
