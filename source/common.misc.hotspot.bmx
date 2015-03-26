SuperStrict
Import "Dig/base.framework.entity.bmx"
Import "Dig/base.framework.tooltip.bmx"
Import "Dig/base.util.event.bmx"
Import "Dig/base.util.input.bmx"


Type THotspot Extends TRenderableEntity
	Field name:String = ""
	Field tooltip:TTooltip
	Field tooltipEnabled:Int = True
	Field tooltipText:String = ""
	Field tooltipDescription:String	= ""
	Field hovered:Int = False
	Field enterable:Int = False
	Global list:TList = CreateList()


	Method Create:THotSpot(name:String, x:Int,y:Int,w:Int,h:Int)
		area = New TRectangle.Init(x,y,w,h)
		Self.name = name

		list.AddLast(Self)
		Return Self
	End Method


	Function Get:THotspot(id:Int)
		For Local hotspot:THotspot = EachIn list
			If hotspot.id = id Then Return hotspot
		Next

		Return Null
	End Function


	Method setTooltipText( text:String="", description:String="" )
		Self.tooltipText		= text
		Self.tooltipDescription = description
	End Method


	Method GetTooltip:TTooltip()
		'return the first tooltip found in children
		For Local t:TTooltip = EachIn childEntities
			Return t
		Next
		Return Null
	End Method


	Method SetEnterable(bool:Int = True)
		enterable = bool
	End Method


	Method IsEnterable:Int()
		Return enterable
	End Method


	'update tooltip
	'handle clicks -> send events so eg can send figure to it
	Method Update:Int()
		hovered = False
	
		If GetScreenArea().containsXY(MouseManager.x, MouseManager.y)
			hovered = True
			If MOUSEMANAGER.isClicked(1)
				EventManager.triggerEvent( TEventSimple.Create("hotspot.onClick", New TData , Self ) )
			EndIf
		EndIf

		If hovered And tooltipEnabled
			If tooltip
				tooltip.Hover()
			ElseIf tooltipText<>""
				'create it
				tooltip = TTooltip.Create(tooltipText, tooltipDescription, 100, 140, 0, 0)
				'layout the tooltip centered above the hotspot
				tooltip.area.position.SetXY(area.GetW()/2 - tooltip.GetWidth()/2, -tooltip.GetHeight())
				tooltip.enabled = True

				AddChild(tooltip)
			EndIf
		EndIf

		UpdateChildren()

		'delete old tooltips
		If tooltip And tooltip.lifetime < 0 Then RemoveChild(tooltip)
	End Method
End Type