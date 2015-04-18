SuperStrict
Import brl.Map
Import brl.WAVLoader
Import brl.OGGLoader
Import "base.util.logger.bmx"
Import "base.util.vector.bmx"

Import "base.sfx.soundstream.bmx"



Type TSoundManager
	Field soundFiles:TMap = CreateMap()
	Field activeMusicChannel:TChannel = Null
	Field inactiveMusicChannel:TChannel = Null

	Field sfxVolume:Float = 1
	Field defaulTSfxDynamicSettings:TSfxSettings = Null

	Field sfxOn:Int = 1
	Field musicOn:Int = 1
	Field musicVolume:Float = 1
	Field nextMusicVolume:Float = 1
	Field lastTitleNumber:Int = 0
	Field inactiveMusicStream:TDigAudioStream = Null
	Field activeMusicStream:TDigAudioStream = Null
	Field nextMusicStream:TDigAudioStream = Null

	Field forceNextMusic:Int = 0
	Field fadeProcess:Int = 0 '0 = nicht aktiv  1 = aktiv
	Field fadeOutVolume:Int = 1000
	Field fadeInVolume:Int = 0

	Field soundSources:TMap = CreateMap()
	Field receiver:TSoundSourcePosition

	Field _currentPlaylistName:String = "default"
	'a named array of playlists, playlists contain available musicStreams
	Field playlists:TMap = CreateMap()

	'do auto crossfade X seconds before song end
	'use 0 to disable that feature
	Field autoCrossFadeTime:int = 2
	'disable to skip fading on next song switch 
	Field autoCrossFadeNextSong:int = True

	Global instance:TSoundManager

	Global PREFIX_MUSIC:String = "MUSIC_"
	Global PREFIX_SFX:String = "SFX_"

	Global audioEngineEnabled:int = True
	Global audioEngine:String = "AUTOMATIC"


	Function Create:TSoundManager()
		Local manager:TSoundManager = New TSoundManager

		'initialize sound system
		InitAudioEngine()

		manager.defaulTSfxDynamicSettings = TSfxSettings.Create()
		Return manager
	End Function


	Function SetAudioEngine(engine:string)
		'limit to allowed engines
		Select engine.ToUpper()
			case "NONE"
				audioEngine = "NONE"

			case "LINUX_ALSA"
				audioEngine = "FreeAudio ALSA System"
			case "LINUX_PULSE"
				audioEngine = "FreeAudio PulseAudio System"
			case "LINUX_OSS"
				audioEngine = "FreeAudio OpenSound System"

			case "MACOSX_CORE"
				audioEngine = "FreeAudio CoreAudio"

			case "WINDOWS_MM"
				audioEngine = "FreeAudio Multimedia"
			case "WINDOWS_DS"
				audioEngine = "FreeAudio DirectSound"

			default
				audioEngine = "AUTOMATIC"
		End Select
	End Function


	Function InitSpecificAudioEngine:int(engine:string)
		if engine = "AUTOMATIC" then engine = "FreeAudio"
		If Not SetAudioDriver(engine)
			if engine = audioEngine
				TLogger.Log("SoundManager.SetAudioEngine()", "audio engine ~q"+engine+"~q (configured) failed.", LOG_ERROR)
			else
				TLogger.Log("SoundManager.SetAudioEngine()", "audio engine ~q"+engine+"~q failed.", LOG_ERROR)
			endif
			Return False
		Else
			Return True
		endif
	End Function


	Function InitAudioEngine:int()
		local engines:String[] = [audioEngine]
		'add automatic-engine if manual setup is not already set to it
		if audioEngine <> "AUTOMATIC" then engines :+ ["AUTOMATIC"]

		?Linux
			if audioEngine <> "FreeAudio PulseAudio System" then engines :+ ["FreeAudio PulseAudio System"]
			if audioEngine <> "FreeAudio ALSA System" then engines :+ ["FreeAudio ALSA System"]
			if audioEngine <> "FreeAudio OpenSound System" then engines :+ ["FreeAudio OpenSound System"]
		?MacOS
			'ATTENTION: WITHOUT ENABLED SOUNDCARD THIS CRASHES!
			engines :+ ["FreeAudio CoreAudio"]
		?Win32
			engines :+ ["FreeAudio Multimedia"]
			engines :+ ["FreeAudio DirectSound"]
		?

		'try to init one of the engines, starting with the manually set
		'audioEngine
		local foundWorkingEngine:string = ""
		if audioEngine <> "NONE"
			For local engine:string = eachin engines
				if InitSpecificAudioEngine(engine)
					foundWorkingEngine = engine
					exit
				endif
			Next
		endif

		'if no sound engine initialized successfully, use the dummy
		'output (no sound)
		if foundWorkingEngine = ""
			TLogger.Log("SoundManager.SetAudioEngine()", "No working audio engine found. Disabling sound.", LOG_ERROR)
			DisableAudioEngine()
			Return False
		endif

		TLogger.Log("SoundManager.SetAudioEngine()", "initialized with engine ~q"+foundWorkingEngine+"~q.", LOG_DEBUG)
		Return True
	End Function


	Function GetInstance:TSoundManager()
		If Not instance Then instance = TSoundManager.Create()
		Return instance
	End Function


	Function DisableAudioEngine:int()
		audioEngineEnabled = False
	End Function


	'use 0 to disable feature
	Method SetAutoCrossfadeTime:int(seconds:int = 0)
		autoCrossFadeTime = seconds
	End Method


	Method GetDefaultReceiver:TSoundSourcePosition()
		Return receiver
	End Method


	Method SetDefaultReceiver(_receiver:TSoundSourcePosition)
		receiver = _receiver
	End Method


	'playlists is a comma separated string of playlists this music wants to
	'be stored in
	Method AddSound:Int(name:String, sound:Object, playlists:String="default")
		Self.soundFiles.insert(Lower(name), sound)

		Local playlistsArray:String[] = playlists.split(",")
		For Local playlist:String = EachIn playlistsArray
			playlist = playlist.Trim() 'remove whitespace
			AddSoundToPlaylist(playlist, name, sound)
		Next
	End Method


	Method AddSoundToPlaylist(playlist:String="default", name:String, sound:Object)
		If TSound(sound)
			playlist = PREFIX_SFX + Lower(playlist)
		ElseIf TDigAudioStream(sound)
			playlist = PREFIX_MUSIC + Lower(playlist)
		EndIf
		name = Lower(name)

		'if not done yet - create a new playlist entry
		'fetch the playlist
		Local playlistContainer:TList
		If Not playlists.contains(playlist)
			playlistContainer = CreateList()
			playlists.insert(playlist, playlistContainer)
		Else
			playlistContainer = TList(playlists.ValueForKey(playlist))
		EndIf
		playlistContainer.AddLast(sound)
	End Method


	Method GetCurrentPlaylist:String()
		Return _currentPlaylistName:String
	End Method


	Method SetCurrentPlaylist(name:String="default")
		_currentPlaylistName = name
	End Method


	'use this method if multiple sfx for a certain event are possible
	'(so eg. multiple "door open/close"-sounds to make variations
	Method GetRandomSfxFromPlaylist:TSound(playlist:String)
		Local playlistContainer:TList = TList(playlists.ValueForKey(PREFIX_SFX + playlist))
		If Not playlistContainer Then Print "playlist: "+playlist+" not found."; Return Null
		If playlistContainer.count() = 0 Then Print "empty list:"+PREFIX_SFX + playlist; Return Null

		Return TSound(playlistContainer.ValueAtIndex(Rand(0, playlistContainer.count()-1)))
	End Method


	'if avoidMusic is set, the function tries to return another music (if possible)
	Method GetRandomMusicFromPlaylist:TDigAudioStream(playlist:String, avoidMusic:TDigAudioStream = Null)
		Local playlistContainer:TList = TList(playlists.ValueForKey(PREFIX_MUSIC + playlist))
		If Not playlistContainer
			'TLogger.Log("GetRandomMusicFromPlaylist", "No playlist: "+playlist+" found.", LOG_WARNING)
			Return Null
		EndIf
		If playlistContainer.count() = 0
			'TLogger.Log("GetRandomMusicFromPlaylist", "playlist: "+playlist+" is empty.", LOG_WARNING)
			Return Null
		EndIf

		Local result:TDigAudioStream
		'try to find another music file
		If avoidMusic And playlistContainer.count()>1
			Repeat
				result = TDigAudioStream(playlistContainer.ValueAtIndex(Rand(0, playlistContainer .count()-1)))
			Until result <> avoidMusic
		Else
			result = TDigAudioStream(playlistContainer.ValueAtIndex(Rand(0, playlistContainer .count()-1)))
		EndIf
		Return result
	End Method


	Method RegisterSoundSource:int(soundSource:TSoundSourceElement)
		if not soundSource then return False
		If Not soundSources.ValueForKey(soundSource.GetGUID())
			soundSources.Insert(soundSource.GetGUID(), soundSource)
		endif
	End Method


	Method GetSoundSource:TSoundSourceElement(GUID:string)
		return TSoundSourceElement(soundSources.ValueForKey(GUID))
	End Method

	

	Method IsPlaying:Int()
		If Not activeMusicChannel Then Return False
		Return activeMusicChannel.Playing()
	End Method


	Method Mute:Int(bool:Int=True)
		If bool
			TLogger.Log("TSoundManager.Mute()", "Muting all sounds", LOG_DEBUG)
		Else
			TLogger.Log("TSoundManager.Mute()", "Unmuting all sounds", LOG_DEBUG)
		EndIf
		MuteSfx(bool)
		MuteMusic(bool)
	End Method


	Method MuteSfx:Int(bool:Int=True)
		If bool
			TLogger.Log("TSoundManager.MuteSfx()", "Muting all sound effects", LOG_DEBUG)
		Else
			TLogger.Log("TSoundManager.MuteSfx()", "Unmuting all sound effects", LOG_DEBUG)
		EndIf
		For Local element:TSoundSourceElement = EachIn soundSources.Values()
			element.mute(bool)
		Next

		sfxOn = Not bool
	End Method


	Method MuteMusic:Int(bool:Int=True)
		if not audioEngineEnabled then return False

		If bool
			TLogger.Log("TSoundManager.MuteMusic()", "Muting music", LOG_DEBUG)
		Else
			TLogger.Log("TSoundManager.MuteMusic()", "Unmuting music", LOG_DEBUG)
		EndIf

		If bool
			If activeMusicChannel Then PauseChannel(activeMusicChannel)
			If inactiveMusicChannel Then inactiveMusicChannel.Stop()
		Else
			If activeMusicChannel Then ResumeChannel(activeMusicChannel)
		EndIf
		musicOn = Not bool
	End Method


	Method IsMuted:Int()
		If sfxOn Or musicOn Then Return False
		Return True
	End Method


	Method HasMutedMusic:Int()
		Return Not musicOn
	End Method


	Method HasMutedSfx:Int()
		Return Not sfxOn
	End Method


	Method Update:Int()
		'skip updates if muted
		If isMuted() Then Return True

		If sfxOn
			For Local element:TSoundSourceElement = EachIn soundSources.Values()
				element.Update()
			Next
		EndIf

		If Not HasMutedMusic()
			'Wenn der Musik-Channel nicht l�uft, dann muss nichts gemacht werden
			If Not activeMusicChannel Then Return True

			'refill buffers
			If inactiveMusicStream then inactiveMusicStream.Update()
			If activeMusicStream then activeMusicStream.Update()


			'autocrossfade to the next song
			if autoCrossFadeTime > 0 and autoCrossFadeNextSong and activeMusicStream
				if activeMusicStream.GetTimeLeft() < autoCrossFadeTime
					PlayMusicPlaylist(GetCurrentPlaylist())
				endif
			endif


			'if the music didn't stop yet
			If activeMusicChannel.Playing()
				If (forceNextMusic And nextMusicStream) Or fadeProcess > 0
					'TLogger.log("TSoundManager.Update()", "FadeOverToNextTitle", LOG_DEBUG)
					FadeOverToNextTitle()
				EndIf
			'no music is playing, just start
			Else
				TLogger.Log("TSoundManager.Update()", "PlayMusicPlaylist", LOG_DEBUG)
				PlayMusicPlaylist(GetCurrentPlaylist())

				'enable autocrossfading for next song if disabled in the
				'past (eg through playing the same song twice)
				if autoCrossFadeTime > 0 then autoCrossFadeNextSong = True
			EndIf
		EndIf
	End Method


	Method FadeOverToNextTitle:int()
		if not audioEngineEnabled then return False

		If (fadeProcess = 0) Then
			fadeProcess = 1
			inactiveMusicChannel = nextMusicStream.CreateChannel(0)
			ResumeChannel(inactiveMusicChannel)

			inactiveMusicStream = activeMusicStream
			activeMusicStream = nextMusicStream
			nextMusicStream = Null

			forceNextMusic = False
			fadeOutVolume = 1000
			fadeInVolume = 0
		EndIf

		If (fadeProcess = 1) Then 'Das fade out des aktiven Channels
			fadeOutVolume :- 15
			activeMusicChannel.SetVolume(fadeOutVolume/1000.0 * musicVolume)

			fadeInVolume :+ 15
			inactiveMusicChannel.SetVolume(fadeInVolume/1000.0 * nextMusicVolume)
		EndIf

		If fadeOutVolume <= 0 And fadeInVolume >= 1000 Then
			fadeProcess = 0 'Prozess beendet
			musicVolume = nextMusicVolume
			SwitchMusicChannels()
		EndIf
	End Method


	Method SwitchMusicChannels()
		Local channelTemp:TChannel = Self.activeMusicChannel
		Self.activeMusicChannel = Self.inactiveMusicChannel
		Self.inactiveMusicChannel = channelTemp

		Self.inactiveMusicChannel.Stop()
	End Method


	Method PlaySfx:int(sfx:TSound, channel:TChannel)
		if not audioEngineEnabled then return False

		If Not HasMutedSfx() And sfx Then PlaySound(sfx, Channel)
	End Method


	Method PlayMusicPlaylist(playlist:String)
		PlayMusicOrPlayList(playlist, True)
	End Method


	Method PlayMusic(music:String)
		PlayMusicOrPlayList(music, False)
	End Method


	Method PlayMusicOrPlaylist:Int(name:String, fromPlaylist:Int=False)
		if not audioEngineEnabled then return False

		If HasMutedMusic() Then Return True

		If fromPlaylist
			nextMusicStream = GetMusicStream("", name)
			nextMusicVolume = GetMusicVolume(name)
			If nextMusicStream
				SetCurrentPlaylist(name)
				TLogger.Log("PlayMusicOrPlaylist", "GetMusicStream from Playlist ~q"+name+"~q. Also set current playlist to it.", LOG_DEBUG)
			Else
				TLogger.Log("PlayMusicOrPlaylist", "GetMusicStream from Playlist ~q"+name+"~q not possible. No Playlist.", LOG_DEBUG)
			EndIf
		Else
			nextMusicStream = GetMusicStream(name, "")
			nextMusicVolume = GetMusicVolume(name)
			TLogger.Log("PlayMusicOrPlaylist", "GetMusicStream by name ~q"+name+"~q", LOG_DEBUG)
		EndIf

		if not nextMusicStream
			TLogger.Log("PlayMusicOrPlaylist", "Music not found. Using random from default playlist", LOG_DEBUG)
			nextMusicStream = GetRandomMusicFromPlaylist("default")
			nextMusicVolume = 1
		endif

		forceNextMusic = True
		
		'Wenn der Musik-Channel noch nicht laeuft, dann jetzt starten
		If Not activeMusicChannel Or Not activeMusicChannel.Playing()
			If Not nextMusicStream
				TLogger.Log("PlayMusicOrPlaylist", "could not start activeMusicChannel: no next music found", LOG_DEBUG)
			Else
				TLogger.Log("PlayMusicOrPlaylist", "start activeMusicChannel", LOG_DEBUG)
				Local musicVolume:Float = nextMusicVolume
				activeMusicChannel = nextMusicStream.CreateChannel(musicVolume)

				ResumeChannel(activeMusicChannel)

				inactiveMusicStream = activeMusicStream
				activeMusicStream = nextMusicStream

				forceNextMusic = False
			EndIf
		EndIf


		'While playMusicPlayList will return the next song,
		'there is no guarantee that it does not return the
		'same song again
		'the nature of the stream's buffer is, that you
		'cannot play 1 stream in 2 different channels

		'that is why fading needs a clone if songs are the same
		if autoCrossFadeNextSong and nextMusicStream
			if nextMusicStream = activeMusicStream
				'print "playing same song: creating clone"
				nextMusicStream = activeMusicStream.Clone()
				nextMusicVolume = musicVolume
			endif
		endif		
	End Method


	'returns if there would be a stream to play
	'use this to avoid music changes if there is no new stream available
	Method HasMusicStream:Int(music:String="", playlist:String="")
		If playlist=""
			Return Null <> TDigAudioStream(soundFiles.ValueForKey(Lower(music)))
		Else
			Return Null <> GetRandomMusicFromPlaylist(playlist, nextMusicStream)
		EndIf
	End Method


	Method GetMusicStream:TDigAudioStream(music:String="", playlist:String="")
		Local result:TDigAudioStream

		If playlist=""
			result = TDigAudioStream(soundFiles.ValueForKey(Lower(music)))
			TLogger.Log("TSoundManager.GetMusicStream()", "Play music: " + music, LOG_DEBUG)
		Else
			'try to get a song differing to the current one
			result = GetRandomMusicFromPlaylist(playlist, activeMusicStream)
			'result = GetRandomMusicFromPlaylist(playlist, nextMusicStream)
			Rem
			if result
				TLogger.log("TSoundManager.GetMusicStream()", "Play random music from playlist: ~q" + playlist +"~q  file: ~q"+result.url+"~q", LOG_DEBUG)
			else
				TLogger.log("TSoundManager.GetMusicStream()", "Cannot play random music from playlist: ~q" + playlist +"~q, nothing found.", LOG_DEBUG)
			endif
			endrem
		EndIf

		Return result
	End Method


	Method GetSfx:TSound(sfx:String="", playlist:String="")
		Local result:TSound
		If playlist=""
			result = TSound(soundFiles.ValueForKey(Lower(sfx)))
			'TLogger.log("TSoundManager.GetSfx()", "Play sfx: " + sfx, LOG_DEBUG)
		Else
			result = GetRandomSfxFromPlaylist(playlist)
			'TLogger.log("TSoundManager.GetSfx()", "Play random sfx from playlist: " + playlist, LOG_DEBUG)
		EndIf

		Return result
	End Method


	'by default all sfx share the same volume
	Method GetSfxVolume:Float(sfx:String)
		Return 0.2
	End Method

	'by default all music share the same volume
	Method GetMusicVolume:Float(music:String)
		Return 1.0
	End Method
End Type

'===== CONVENIENCE ACCESSORS =====
'convenience instance getter
Function GetSoundManager:TSoundManager()
	return TSoundManager.GetInstance()
End Function




'Diese Basisklasse ist ein Wrapper f�r einen normalen Channel mit erweiterten Funktionen
Type TSfxChannel
	Field Channel:TChannel = AllocChannel()
	Field CurrentSfx:String
	Field CurrentSettings:TSfxSettings
	Field MuteAfterCurrentSfx:Int


	Function Create:TSfxChannel()
		Return New TSfxChannel
	End Function


	Method PlaySfx(sfx:String, settings:TSfxSettings=Null)
		CurrentSfx = sfx
		CurrentSettings = settings

		AdjustSettings(False)

		Local sound:TSound = TSoundManager.GetInstance().GetSfx(sfx)
		TSoundManager.GetInstance().PlaySfx(sound, Channel)
	End Method


	Method PlayRandomSfx(playlist:String, settings:TSfxSettings=Null)
		CurrentSfx = playlist
		CurrentSettings = settings

		AdjustSettings(False)

		Local sound:TSound = TSoundManager.GetInstance().GetSfx("", playlist)
		TSoundManager.GetInstance().PlaySfx(sound, Channel)
		'if sound then PlaySound(sound, channel)
	End Method


	Method IsActive:Int()
		Return Channel.Playing()
	End Method


	Method Stop()
		Channel.Stop()
	End Method


	Method Mute(bool:Int=True)
		If bool
			If MuteAfterCurrentSfx And IsActive()
				AdjustSettings(True)
			Else
				Channel.SetVolume(0)
			EndIf
		Else
			Channel.SetVolume(TSoundManager.GetInstance().sfxVolume)
		EndIf
	End Method


	Method AdjustSettings(isUpdate:Int)
		If Not isUpdate
			channel.SetVolume(TSoundManager.GetInstance().sfxVolume * 0.75 * CurrentSettings.GetVolume()) '0.75 ist ein fixer Wert die Lautst�rke der Sfx reduzieren soll
		EndIf
	End Method
End Type




'Der dynamische SfxChannel hat die M�glichkeit abh�ngig von der Position von Sound-Quelle und Empf�nger dynamische Modifikationen an den Einstellungen vorzunehmen. Er wird bei jedem Update aktualisiert.
Type TDynamicSfxChannel Extends TSfxChannel
	Field Source:TSoundSourceElement
	Field Receiver:TSoundSourcePosition


	Function CreateDynamicSfxChannel:TSfxChannel(source:TSoundSourceElement=Null)
		Local sfxChannel:TDynamicSfxChannel = New TDynamicSfxChannel
		sfxChannel.Source = source
		Return sfxChannel
	End Function


	Method SetReceiver(_receiver:TSoundSourcePosition)
		Self.Receiver = _receiver
	End Method


	Method AdjustSettings(isUpdate:Int)
		Local sourcePoint:TVec3D = Source.GetCenter()
		Local receiverPoint:TVec3D = Receiver.GetCenter() 'Meistens die Position der Spielfigur

		If CurrentSettings.forceVolume
			channel.SetVolume(CurrentSettings.defaultVolume)
			'print "Volume:" + CurrentSettings.defaultVolume
		Else
			'Lautst�rke ist Abh�ngig von der Entfernung zur Ger�uschquelle
			Local distanceVolume:Float = CurrentSettings.GetVolumeByDistance(Source, Receiver)
			channel.SetVolume(TSoundManager.GetInstance().sfxVolume * distanceVolume) ''0.75 ist ein fixer Wert die Lautst�rke der Sfx reduzieren soll
			'print "Volume: " + (SoundManager.sfxVolume * distanceVolume)
		EndIf

		If (sourcePoint.z = 0) Then
			'170 Grenzwert = Erst aber dem Abstand von 170 (gef�hlt/gesch�tzt) h�rt man nur noch von einer Seite.
			'Ergebnis sollte ungef�hr zwischen -1 (links) und +1 (rechts) liegen.
			If CurrentSettings.forcePan
				channel.SetPan(CurrentSettings.defaultPan)
			Else
				channel.SetPan(Float(sourcePoint.x - receiverPoint.x) / 170)
			EndIf
			channel.SetDepth(0) 'Die Tiefe spielt keine Rolle, da elementPoint.z = 0
		Else
			Local zDistance:Float = Abs(sourcePoint.z - receiverPoint.z)

			If CurrentSettings.forcePan
				channel.SetPan(CurrentSettings.defaultPan)
				'print "Pan:" + CurrentSettings.defaultPan
			Else
				Local xDistance:Float = Abs(sourcePoint.x - receiverPoint.x)
				Local yDistance:Float = Abs(sourcePoint.y - receiverPoint.y)

				Local angleZX:Float = ATan(zDistance / xDistance) 'Winkelfunktion: Welchen Winkel hat der H�rer zur Soundquelle. 90� = davor/dahiner    0� = gleiche Ebene	tan(alpha) = Gegenkathete / Ankathete

				Local rawPan:Float = ((90 - angleZX) / 90)
				Local panCorrection:Float = Max(0, Min(1, xDistance / 170)) 'Den r/l Effekt sollte noch etwas abgeschw�cht werden, wenn die Quelle nah ist
				Local correctPan:Float = rawPan * panCorrection

				'0� => Aus einer Richtung  /  90� => aus beiden Richtungen
				If (sourcePoint.x < receiverPoint.x) Then 'von links
					channel.SetPan(-correctPan)
					'print "Pan:" + (-correctPan) + " - angleZX: " + angleZX + " (" + xDistance + "/" + zDistance + ")    # " + rawPan + " / " + panCorrection
				ElseIf (sourcePoint.x > receiverPoint.x) Then 'von rechts
					channel.SetPan(correctPan)
					'print "Pan:" + correctPan + " - angleZX: " + angleZX + " (" + xDistance + "/" + zDistance + ")    # " + rawPan + " / " + panCorrection
				Else
					channel.SetPan(0)
				EndIf
			EndIf

			If CurrentSettings.forceDepth
				channel.SetDepth(CurrentSettings.defaultDepth)
				'print "Depth:" + CurrentSettings.defaultDepth
			Else
				Local angleOfDepth:Float = ATan(receiverPoint.DistanceTo(sourcePoint, False) / zDistance) '0 = direkt hinter mir/vor mir, 90� = �ber/unter/neben mir

				If sourcePoint.z < 0 Then 'Hintergrund
					channel.SetDepth(-((90 - angleOfDepth) / 90)) 'Minuswert = Hintergrund / Pluswert = Vordergrund
					'print "Depth:" + (-((90 - angleOfDepth) / 90)) + " - angle: " + angleOfDepth + " (" + receiverPoint.DistanceTo(sourcePoint, false) + "/" + zDistance + ")"
				ElseIf sourcePoint.z > 0 Then 'Vordergrund
					channel.SetDepth((90 - angleOfDepth) / 90) 'Minuswert = Hintergrund / Pluswert = Vordergrund
					'print "Depth:" + ((90 - angleOfDepth) / 90) + " - angle: " + angleOfDepth + " (" + receiverPoint.DistanceTo(sourcePoint, false) + "/" + zDistance + ")"
				EndIf
			EndIf
		EndIf
	End Method
End Type




Type TSfxSettings
	Field forceVolume:Float = False
	Field forcePan:Float = False
	Field forceDepth:Float = False

	Field defaultVolume:Float = 1
	Field defaultPan:Float = 0
	Field defaultDepth:Float = 0

	Field nearbyDistanceRange:Int = -1
'	Field nearbyDistanceRangeTopY:int -1
'	Field nearbyDistanceRangeBottomY:int -1   hier war ich
	Field maxDistanceRange:Int = 1000

	Field nearbyRangeVolume:Float = 1
	Field midRangeVolume:Float = 0.8
	Field minVolume:Float = 0


	Function Create:TSfxSettings()
		Return New TSfxSettings
	End Function


	Method GetVolume:Float()
		Return defaultVolume
	End Method


	Method GetVolumeByDistance:Float(source:TSoundSourceElement, receiver:TSoundSourcePosition)
		Local currentDistance:Int = source.GetCenter().DistanceTo(receiver.getCenter())

		Local result:Float = midRangeVolume
		If (currentDistance <> -1) Then
			If currentDistance > Self.maxDistanceRange Then 'zu weit weg
				result = Self.minVolume
			ElseIf currentDistance < Self.nearbyDistanceRange Then 'sehr nah dran
				result = Self.nearbyRangeVolume
			Else 'irgendwo dazwischen
				result = midRangeVolume * (Float(Self.maxDistanceRange) - Float(currentDistance)) / Float(Self.maxDistanceRange)
			EndIf
		EndIf

		Return result
	End Method
End Type




Type TSoundSourcePosition 'Basisklasse f�r verschiedene Wrapper
	Field ID:int = 0
	Global _lastID:int = 0

	Method GetCenter:TVec3D() Abstract
	Method IsMovable:Int() Abstract
	Method GetClassIdentifier:string() Abstract


	Method New()
		_lastID :+ 1
		ID = _lastID
	End Method


	Method GetGUID:string()
		return GetClassIdentifier()+"-"+ID
	End Method
End Type




Type TSoundSourceElement Extends TSoundSourcePosition
	Field GUID:String = ""
	Field SfxChannels:TMap = CreateMap()

	Method GetIsHearable:Int() Abstract
	Method GetChannelForSfx:TSfxChannel(sfx:String) Abstract
	Method GetSfxSettings:TSfxSettings(sfx:String) Abstract
	Method OnPlaySfx:Int(sfx:String) Abstract


	Method GetGUID:string()
		if GUID = "" then return GetClassIdentifier()+"-"+ID
		return GUID
	End Method


	Method SetGUID(newGUID:string)
		GUID = newGUID
	End Method


	Method GetReceiver:TSoundSourcePosition()
		Return TSoundManager.GetInstance().GetDefaultReceiver()
	End Method


	Method PlayRandomSfx(playlist:String, sfxSettings:TSfxSettings=Null)
		PlaySfxOrPlaylist(playlist, sfxSettings, True)
	End Method


	Method PlaySfx(sfx:String, sfxSettings:TSfxSettings=Null)
		PlaySfxOrPlaylist(sfx, sfxSettings, False)
	End Method


	Method PlaySfxOrPlaylist(name:String, sfxSettings:TSfxSettings=Null, playlistMode:Int=False)
		If Not GetIsHearable() Then Return
		If Not OnPlaySfx(name) Then Return
		'print GetGUID() + " # PlaySfx: " + sfx

		TSoundManager.GetInstance().RegisterSoundSource(Self)

		Local channel:TSfxChannel = GetChannelForSfx(name)
		Local settings:TSfxSettings = sfxSettings
		If settings = Null Then settings = GetSfxSettings(name)

		If TDynamicSfxChannel(channel)
			TDynamicSfxChannel(channel).SetReceiver(GetReceiver())
		EndIf

		If playlistMode
			channel.PlayRandomSfx(name, settings)
		Else
			channel.PlaySfx(name, settings)
		EndIf
		'print GetGUID() + " # End PlaySfx: " + sfx
	End Method


	Method PlayOrContinueRandomSfx(playlist:String, sfxSettings:TSfxSettings=Null)
		PlayOrContinueSfxOrPlaylist(playlist, sfxSettings, True)
	End Method


	Method PlayOrContinueSfx(sfx:String, sfxSettings:TSfxSettings=Null)
		PlayOrContinueSfxOrPlaylist(sfx, sfxSettings, False)
	End Method


	Method PlayOrContinueSfxOrPlaylist(name:String, sfxSettings:TSfxSettings=Null, playlistMode:Int=False)
		Local channel:TSfxChannel = GetChannelForSfx(name)
		If Not channel.IsActive()
			'Print "PlayOrContinueSfx: start"
			PlaySfxOrPlaylist(name, sfxSettings, playlistMode)
		Else
			'Print "PlayOrContinueSfx: Continue"
		EndIf
	End Method


	Method Stop(sfx:String)
		Local channel:TSfxChannel = GetChannelForSfx(sfx)
		channel.Stop()
	End Method


	Method Mute:Int(bool:Int=True)
		For Local sfxChannel:TSfxChannel = EachIn MapValues(SfxChannels)
			sfxChannel.Mute(bool)
		Next
	End Method


	Method Update()
		If GetIsHearable()
			For Local sfxChannel:TSfxChannel = EachIn MapValues(SfxChannels)
				If sfxChannel.IsActive() Then sfxChannel.AdjustSettings(True)
			Next
		Else
			For Local sfxChannel:TSfxChannel = EachIn MapValues(SfxChannels)
				sfxChannel.Mute()
			Next
		EndIf
	End Method


	Method AddDynamicSfxChannel:TSfxChannel(name:String, muteAfterSfx:Int=False)
		Local sfxChannel:TSfxChannel = TDynamicSfxChannel.CreateDynamicSfxChannel(Self)
		sfxChannel.MuteAfterCurrentSfx = muteAfterSfx
		SfxChannels.insert(name, sfxChannel)
		Return sfxChannel
	End Method


	Method GetSfxChannelByName:TSfxChannel(name:String)
		Return TSfxChannel(MapValueForKey(SfxChannels, name))
	End Method
End Type