#if defined _natives_TF2HudMsg
 #endinput
#endif
#define _natives_TF2HudMsg

#include <sourcemod>
#include "morecolors.inc"
#include <tf2_stocks>

#include "tf2hudmsg.inc"

// Some usefull links:
// all dumps: https://github.com/powerlord/tf2-data
// annotations: https://forums.alliedmods.net/showthread.php?p=1946768
//   tf_hud_annotationspanel.cpp <- These use EditablePanel, so can use #LocalizationKeys
// hudnotifycustom: https://forums.alliedmods.net/showthread.php?t=155911

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
	name = "[TF2] Hud Msg",
	author = "reBane",
	description = "Providing natives for some Hud Elements and managing Cursor Annotation indices",
	version = "21w34a",
	url = "N/A"
}

public void OnPluginStart() {
	updateAnnotationsMapchange();
}


public void OnMapStart() {
	updateAnnotationsMapchange();
}

#define MAX_ANNOTATION_COUNT 50*MAXPLAYERS

enum struct AnnotationData {
	int followEntity;
	bool idused;
	float pos[3];
	float lifetime;
	float timeoutestimate; // the time where this annotation will be timed out (through lifetime after Send)
	bool autoclose; //automatically reset the idused state after timeoutestimate or hide -> fire and forget
	int visibility;
	char text[MAX_ANNOTATION_LENGTH];
	bool isDeployed;
	any plugindata;
	
	void VisibleFor(int client, bool visible=true) {
		//this will not work with more than 32 clients
		if (visible) this.visibility |= (1<<client);
		else this.visibility &=~ (1<<client);
	}
	void SetText(const char[] text) {
		strcopy(this.text, MAX_ANNOTATION_LENGTH, text);
	}
	void SetParent(int entity) {
		if (!IsValidEdict(entity)) this.followEntity = INVALID_ENT_REFERENCE;
		else this.followEntity = (entity >= 0) ? EntIndexToEntRef(entity) : entity;
	}
	bool IsPlaying() {
		if (this.timeoutestimate <= GetGameTime()) {
			if (this.autoclose) this.idused = false;
			this.isDeployed = false;
		}
		return this.isDeployed;
	}
	/** @return true if the annotaion was sent to clients */
	bool Send(int selfIndex, const char[] sound, bool showEffect = false) {
		if (!(this.isDeployed = !!this.visibility)) return false;
		Event event = CreateEvent("show_annotation");
		if (event == INVALID_HANDLE) return false;
		event.SetFloat("worldPosX", this.pos[0]);
		event.SetFloat("worldPosY", this.pos[1]);
		event.SetFloat("worldPosZ", this.pos[2]);
		event.SetFloat("lifetime", this.lifetime);
		// they seem to have a <bool>"show_distance"
		event.SetInt("id", selfIndex);
		if (!strlen(this.text)) //prevent default *AnnotationPannel_Callout
			event.SetString("text", " ");
		else
			event.SetString("text", this.text);
		event.SetString("play_sound", sound);
		if (this.followEntity != INVALID_ENT_REFERENCE) event.SetInt("follow_entindex", EntRefToEntIndex(this.followEntity));
		if (this.visibility != -1) event.SetInt("visibilityBitfield", this.visibility);
		if (showEffect) event.SetBool("show_effect", showEffect);
		event.Fire();
		this.timeoutestimate = GetGameTime() + (this.lifetime > 0.0 ? this.lifetime : 0.0);
		return true;
	}
	/** @return true if the annotation is hidden after call */
	bool Hide(int selfIndex) {
		if (!this.isDeployed) return true;
		Event event = CreateEvent("hide_annotation");
		if (event == INVALID_HANDLE) return false;
		event.SetInt("id", selfIndex);
		event.Fire();
		this.isDeployed = false;
		if (this.autoclose) this.idused = false;
		return true;
	}
}
AnnotationData annotations[MAX_ANNOTATION_COUNT];
any Impl_CursorAnnotation_new(int index = -1, bool reset=false) {
	if (index < 0) {
		//find free index
		for (int i;i<MAX_ANNOTATION_COUNT;i++) {
			if (!annotations[i].idused) {
				index = i;
				break;
			} else if (annotations[i].autoclose && annotations[i].timeoutestimate <= GetGameTime()) {
				annotations[i].idused = false;
				index = i;
				break;
			}
		}
	}
	if (index < 0 || index >= MAX_ANNOTATION_COUNT) {
		return -1;
	}
	if (!annotations[index].idused || reset) {
		float zero[3];
		annotations[index].visibility = -1;
		annotations[index].followEntity = INVALID_ENT_REFERENCE;
		annotations[index].lifetime = 1000.0;
		annotations[index].SetText("< ERROR >");
		annotations[index].pos = zero;
		annotations[index].idused = true;
		annotations[index].autoclose = false;
		annotations[index].plugindata = 0;
		if (annotations[index].isDeployed) {
			annotations[index].Hide(index);
		}
	}
	return index;
}

void updateAnnotationsMapchange() {
	for (int i;i<MAX_ANNOTATION_COUNT;i++) {
		annotations[i].timeoutestimate = 0.0;
		annotations[i].isDeployed = false;
		if (annotations[i].autoclose) annotations[i].idused = false;
	}
}

/**
 * Displays a HudNotification (centered, bottom half) for the client
 * This element will NOT show with minimal hud!
 * https://forums.alliedmods.net/showthread.php?t=155911
 * @param icon taken from mod_textures.txt
 * @param background (Use a TFTeam or -1 for client team color)
 * @param message (+ format)
 */
void Impl_HudNotificationCustom(int client, const char[] icon="voice_self", int background=-1, bool stripMoreColors=false, const char[] message) {
	if (!IsClientInGame(client) || IsFakeClient(client)) return;
	
	char msg[MAX_MESSAGE_LENGTH];
	strcopy(msg, sizeof(msg), message);
	if (stripMoreColors) CReplaceColorCodes(msg, client, true, sizeof(msg));
	ReplaceString(msg,sizeof(msg),"\"","'");
	if (background < 0) background = view_as<int>(TF2_GetClientTeam(client));
	
	Handle hdl = StartMessageOne("HudNotifyCustom", client);
	BfWriteString(hdl, msg);
	BfWriteString(hdl, icon);
	BfWriteByte(hdl, background);
	EndMessage();
}

// --== NATIVES ==--

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("CursorAnnotation.CursorAnnotation",     Native_CursorAnnotation_new);
	CreateNative("CursorAnnotation.Close",                Native_CursorAnnotation_Close);
	CreateNative("CursorAnnotation.IsValid.get",          Native_CursorAnnotation_IsValid_Get);
	CreateNative("CursorAnnotation.SetVisibilityFor",     Native_CursorAnnotation_SetVisibilityFor);
	CreateNative("CursorAnnotation.SetVisibilityAll",     Native_CursorAnnotation_SetVisibilityAll);
	CreateNative("CursorAnnotation.VisibilityBitmask.get",Native_CursorAnnotation_VisibilityBitmask_Get);
	CreateNative("CursorAnnotation.VisibilityBitmask.set",Native_CursorAnnotation_VisibilityBitmask_Set);
	CreateNative("CursorAnnotation.Data.get",             Native_CursorAnnotation_Data_Get);
	CreateNative("CursorAnnotation.Data.set",             Native_CursorAnnotation_Data_Set);
	CreateNative("CursorAnnotation.SetText",              Native_CursorAnnotation_SetText);
	CreateNative("CursorAnnotation.SetPosition",          Native_CursorAnnotation_SetPosition);
	CreateNative("CursorAnnotation.GetPosition",          Native_CursorAnnotation_GetPosition);
	CreateNative("CursorAnnotation.SetLifetime",          Native_CursorAnnotation_SetLifetime);
	CreateNative("CursorAnnotation.ParentEntity.get",     Native_CursorAnnotation_ParentEntity_Get);
	CreateNative("CursorAnnotation.ParentEntity.set",     Native_CursorAnnotation_ParentEntity_Set);
	CreateNative("CursorAnnotation.IsPlaying.get",        Native_CursorAnnotation_IsPlaying_Get);
	CreateNative("CursorAnnotation.AutoClose.get",        Native_CursorAnnotation_AutoClose_Get);
	CreateNative("CursorAnnotation.AutoClose.set",        Native_CursorAnnotation_AutoClose_Set);
	CreateNative("CursorAnnotation.Update",               Native_CursorAnnotation_Update);
	CreateNative("CursorAnnotation.Hide",                 Native_CursorAnnotation_Hide);
	CreateNative("TF2_HudNotificationCustom",             Native_TF2_HudNotificationCustom);
	CreateNative("TF2_HudNotificationCustomAll",          Native_TF2_HudNotificationCustomAll);
	CreateNative("EscapeVGUILocalization",                Native_EscapeVGUILocalization);
	RegPluginLibrary("tf2hudmsg");
	return APLRes_Success;
}

public any Native_CursorAnnotation_new(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	bool reset = view_as<bool>(GetNativeCell(2));
	
	return Impl_CursorAnnotation_new(index, reset);
}
public any Native_CursorAnnotation_Close(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	
	annotations[index].Hide(index);
	annotations[index].idused = false;
}
public any Native_CursorAnnotation_IsValid_Get(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	
	return index>=0 && index<MAX_ANNOTATION_COUNT && annotations[index].idused;
}
public any Native_CursorAnnotation_SetVisibilityFor(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	int client = view_as<int>(GetNativeCell(2));
	bool visible = view_as<bool>(GetNativeCell(3));
	
	annotations[index].VisibleFor(client, visible);
}
public any Native_CursorAnnotation_SetVisibilityAll(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	bool visible = view_as<bool>(GetNativeCell(2));
	
	annotations[index].visibility = (visible) ? -1 : 0;
}
public any Native_CursorAnnotation_VisibilityBitmask_Get(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	
	return annotations[index].visibility;
}
public any Native_CursorAnnotation_VisibilityBitmask_Set(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	int value = view_as<int>(GetNativeCell(2));
	
	annotations[index].visibility = value;
}
public any Native_CursorAnnotation_Data_Get(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	
	return annotations[index].plugindata;
}
public any Native_CursorAnnotation_Data_Set(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	any value = GetNativeCell(2);
	
	annotations[index].plugindata = value;
}
public any Native_CursorAnnotation_SetText(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	int len;
	GetNativeStringLength(2,len);
	char[] text = new char[len+1];
	GetNativeString(2, text, len+1);
	
	if (StrEqual(annotations[index].text, text)) return false;
	annotations[index].SetText(text);
	return true;
}
public any Native_CursorAnnotation_SetPosition(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	float vec[3];
	GetNativeArray(2,vec,sizeof(vec));
	
	annotations[index].pos = vec;
}
public any Native_CursorAnnotation_GetPosition(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	float vec[3];
	
	vec = annotations[index].pos;
	SetNativeArray(2,vec,sizeof(vec));
}
public any Native_CursorAnnotation_SetLifetime(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	float lifetime = view_as<float>(GetNativeCell(2));
	
	annotations[index].lifetime = lifetime;
}
public any Native_CursorAnnotation_ParentEntity_Get(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	
	return annotations[index].followEntity;
}
public any Native_CursorAnnotation_ParentEntity_Set(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	int entity = view_as<int>(GetNativeCell(2));
	
	annotations[index].SetParent(entity);
}
public any Native_CursorAnnotation_IsPlaying_Get(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	
	return annotations[index].IsPlaying();
}
public any Native_CursorAnnotation_AutoClose_Get(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	
	return annotations[index].autoclose;
}
public any Native_CursorAnnotation_AutoClose_Set(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	bool value = view_as<bool>(GetNativeCell(1));
	
	return annotations[index].autoclose = value;
}
public any Native_CursorAnnotation_Update(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	if (!annotations[index].idused)
		ThrowNativeError(SP_ERROR_INDEX, "The cursor annotation (%i) is closed", index);
	int len;
	GetNativeStringLength(2,len);
	char[] sound = new char[len+1];
	GetNativeString(2,sound,len+1);
	bool effect = view_as<bool>(GetNativeCell(3));
	
	annotations[index].Send(index, sound, effect);
}
public any Native_CursorAnnotation_Hide(Handle plugin, int argc) {
	int index = view_as<int>(GetNativeCell(1));
	
	annotations[index].Hide(index);
}

//native void TF2_HudNotificationCustom(int client, const char[] icon="voice_self", int background=-1, bool stripMoreColors=false, const char[] message, any ...);
public any Native_TF2_HudNotificationCustom(Handle plugin, int argc) {
	int client = view_as<int>(GetNativeCell(1));
	int maxlen;
	GetNativeStringLength(2, maxlen);
	if (maxlen < 0) return;
	char[] icon = new char[maxlen+1];
	GetNativeString(2,icon,maxlen+1);
	int background = view_as<int>(GetNativeCell(3));
	bool stripcol = view_as<bool>(GetNativeCell(4));
	char message[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	FormatNativeString(0,5,6,MAX_MESSAGE_LENGTH,_,message,_);
	
	Impl_HudNotificationCustom(client, icon, background, stripcol, message);
}

//native void TF2_HudNotificationCustomAll(const char[] icon="voice_self", int background=-1, bool stripMoreColors=false, const char[] message, any ...);
public any Native_TF2_HudNotificationCustomAll(Handle plugin, int argc) {
	int maxlen;
	GetNativeStringLength(1, maxlen);
	if (maxlen < 0) return;
	char[] icon = new char[maxlen+1];
	GetNativeString(1,icon,maxlen+1);
	int background = view_as<int>(GetNativeCell(2));
	bool stripcol = view_as<bool>(GetNativeCell(3));
	char message[MAX_MESSAGE_LENGTH];
	
	for (int i=1;i<=MaxClients;i++) {
		SetGlobalTransTarget(i);
		FormatNativeString(0,4,5,MAX_MESSAGE_LENGTH,_,message,_);
		Impl_HudNotificationCustom(i, icon, background, stripcol, message);
	}
}

//native void EscapeVGUILocalization(char[] buffer, int maxsize);
public any Native_EscapeVGUILocalization(Handle plugin, int argc) {
	if (IsNativeParamNullString(1)) return;
	int maxlen = view_as<int>(GetNativeCell(2));
	int inlen;
	char[] buffer = new char[maxlen];
	GetNativeString(1, buffer, maxlen, inlen);
	if (!inlen) return; //string is empty, nothing to do
	
	//prevent #LocalizationKeys from being looked up
	// For a localization to be considered, the string MIGHT start with a number sign but they usually
	// don't contain spaces and are ASCII strings
	// Not being a localization does not modify the string but we have no real way to check if this is
	// a localization or not, so let's just prefix it with a space (barely noticable in annotations)
	bool mightkey=true;
	for(int i=0;i<maxlen;i++) { //check if this matches ^#?\w*$
		if (buffer[i]==0) break;
		if (!('a' <= buffer[i] <= 'z' || 'A' <= buffer[i] <= 'Z' || '0' <= buffer[i] <= '9' || buffer[i]=='_' || buffer[i]=='-' || (!i && buffer[i]=='#'))) {
			mightkey=false;
		}
	}
	if (mightkey) {
		//\x1f is the unit separator and does not render, so we can use it as zero-width non-whitespace prefix
		Format(buffer, maxlen, "\x1f%s", buffer);
	}
	//after looking up #LocalizationKeys, source tries to agressively fill %Placeholders
	//those placeholders usually look like %s1 or something, so we need to get rid of the percent symbols
	ReplaceString(buffer, maxlen, "%", "\xEF\xBC\x85"); //the replacement is a "full wide percent"
	
	//alright, let's copy you back where you belong
	SetNativeString(1, buffer, maxlen);
}
