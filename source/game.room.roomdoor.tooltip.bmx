SuperStrict
Import "Dig/base.framework.tooltip.bmx"
Import "game.room.base.bmx"


Type TRoomDoorTooltip extends TTooltip
	Field roomID:int

	Function Create:TRoomDoorTooltip(title:String = "", content:String = "unknown", x:Int = 0, y:Int = 0, w:Int = -1, h:Int = -1, lifetime:Int = 300)
		local obj:TRoomDoorTooltip = new TRoomDoorTooltip
		obj.Initialize(title, content, x, y, w, h, lifetime)
		return obj
	End Function


	Method AssignRoom(roomID:int)
		self.roomID = roomID
	End Method


	'override to add "blocked" support
	Method DrawBackground:int(x:int, y:int, w:int, h:int)
		local room:TRoomBase = GetRoomBase(roomID)
		if not room then return False

		local oldCol:TColor = new TColor.Get()

		if room.IsBlocked()
			SetColor 255,235,215
		else
			SetColor 255,255,255
		endif
		DrawRect(x, y, w, h)

		oldCol.SetRGB()
	End Method


	'override to modify header col
	Method SetHeaderColor:int()
		local room:TRoomBase = GetRoomBase(roomID)
		if room and room.isBlocked()
			SetColor 250,230,210
		else
			Super.SetHeaderColor()
		endif
	End Method
	


	Method Update:Int()
		local room:TRoomBase = GetRoomBase(roomID)
		if not room then return False

		'adjust image used in tooltip
		If room.name = "archive" Then tooltipimage = 0
		If room.name = "office" Then tooltipimage = 1
		If room.name = "boss" Then tooltipimage = 2
		If room.name = "news" Then tooltipimage = 4
		If room.name.Find("studio",0) = 0 Then tooltipimage = 5
		'adjust header bg color
		If room.owner >= 1 then
			TitleBGtype = room.owner + 10
		Else
			TitleBGtype = 0
		EndIf


		local newTitle:String = room.GetDescription(1)
		if newTitle <> title then SetTitle(newTitle)

		local newContent:String = room.GetDescription(2)
		if room.IsBlocked()
			'add line spacer
			if newContent<>"" then newContent :+ chr(13) + chr(13)
			'add blocked message
			newContent :+ GetLocale("ROOM_IS_BLOCKED")
		endif
		if newContent <> content then SetContent(newContent)

		Super.Update()
		return True
	End Method
End Type
