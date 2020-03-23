﻿unit amLocalization.Persistence;

(*
 * Copyright © 2019 Anders Melander
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *)

interface

uses
  Classes,
  SysUtils,
  amProgress,
  amLocalization.Model;

// -----------------------------------------------------------------------------
//
// TLocalizationProjectFiler
//
// -----------------------------------------------------------------------------
// Save and load project.
// -----------------------------------------------------------------------------
type
  TLocalizationProjectFiler = class
  private
    const
      sModuleKind: array[TLocalizerModuleKind] of string = ('invalid', 'form', 'strings');
      sTranslationStatus: array[TTranslationStatus] of string = ('obsolete', 'pending', 'proposed', '');
      sItemState: array[TLocalizerItemState] of string = ('new', 'unused', '');
      sItemStatus: array[TLocalizerItemStatus] of string = ('', 'hold', 'skip');
  private
    class function EncodeString(const Value: string): string;
    class function DecodeString(const Value: string): string;
  public
    class procedure LoadFromStream(Project: TLocalizerProject; Stream: TStream; const Progress: IProgress = nil);
    class procedure LoadFromFile(Project: TLocalizerProject; const Filename: string; const Progress: IProgress = nil);

    class procedure SaveToStream(Project: TLocalizerProject; Stream: TStream; const Progress: IProgress = nil);
    class procedure SaveToFile(Project: TLocalizerProject; const Filename: string; const Progress: IProgress = nil);
  end;

type
  ELocalizationPersistence = class(Exception);


const
  sLocalizationFileformatRoot = 'xlat';

resourcestring
  sProgressProjectLoading = 'Loading Project';
  sProgressProjectLoad = 'Loading...';
  sProgressProjectReadModules = 'Processing modules...';

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

implementation

uses
  DateUtils,
  IOUtils,
  Windows,
  Variants,
  XMLDoc, XMLIntf,
  System.Character,
  amLocale,
  amPath,
  amVersionInfo;

// -----------------------------------------------------------------------------
//
// TLocalizationProjectFiler
//
// -----------------------------------------------------------------------------
class function TLocalizationProjectFiler.DecodeString(const Value: string): string;
begin
  Result := StringReplace(Value, '##', '#', [rfReplaceAll]);
  Result := StringReplace(Result, '#13', #13, [rfReplaceAll]);
  Result := StringReplace(Result, '#10', #10, [rfReplaceAll]);
  Result := StringReplace(Result, '#9', #9, [rfReplaceAll]);
end;

class function TLocalizationProjectFiler.EncodeString(const Value: string): string;
begin
  Result := StringReplace(Value, '#', '##', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '#13', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '#10', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '#9', [rfReplaceAll]);
end;

// -----------------------------------------------------------------------------

class procedure TLocalizationProjectFiler.LoadFromFile(Project: TLocalizerProject; const Filename: string; const Progress: IProgress);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(Filename, fmOpenRead);
  try
    LoadFromStream(Project, Stream, Progress);
  finally
    Stream.Free;
  end;
end;

// -----------------------------------------------------------------------------

class procedure TLocalizationProjectFiler.LoadFromStream(Project: TLocalizerProject; Stream: TStream; const Progress: IProgress);

  function StringToModuleKind(const Value: string): TLocalizerModuleKind;
  begin
    for Result := Low(Result) To High(Result) do
      if (Value = sModuleKind[Result]) then
        Exit;
    Result := Low(Result);
  end;

  function StringToTranslationStatus(const Value: string): TTranslationStatus;
  begin
    for Result := Low(Result) To High(Result) do
      if (Value = sTranslationStatus[Result]) then
        Exit;
    Result := Low(Result);
  end;

  function StringToItemState(Item: TCustomLocalizerItem; const Value: string): TLocalizerItemStates;
  var
    StateValues: TArray<string>;
    StateValue: string;
    State: TLocalizerItemState;
  begin
    Result := [];
    if (Value = '') then
      Exit;
    StateValues := Value.Split([',']);
    for StateValue in StateValues do
      for State := Low(sItemState) To High(sItemState) do
        if (StateValue = sItemState[State]) then
        begin
          Item.SetState(State);
          Include(Result, State);
          break;
        end;
  end;

  function StringToItemStatus(const Value: string): TLocalizerItemStatus;
  begin
    for Result := Low(Result) To High(Result) do
      if (Value = sItemStatus[Result]) then
        Exit;
    Result := Low(Result);
  end;

  function StringToPropFlags(const Value: string): TPropertyFlags;
  var
    c: Char;
    n: integer;
  begin
    Result := [];
    if (Value = '') then
      Exit;
    for c in Uppercase(Value) do
    begin
      if (c.IsDigit) then
        n := Ord(c)-Ord('0')
      else
        n := 10+Ord(c)-Ord('A');
      if (n >= Ord(Low(TPropertyFlag))) and (n <= Ord(High(TPropertyFlag))) then
        Include(Result, TPropertyFlag(n));
    end;
  end;

var
  XML: IXMLDocument;
  RootNode, ProjectNode: IXMLNode;
  LanguagesNode, LanguageNode: IXMLNode;
  ModulesNode, ModuleNode: IXMLNode;
  ItemsNode, ItemNode: IXMLNode;
  PropsNode, PropNode: IXMLNode;
  XlatsNode, XlatNode: IXMLNode;
  Module: TLocalizerModule;
  Item: TLocalizerItem;
  Prop: TLocalizerProperty;
  Language: TTranslationLanguage;
  CachedLanguage: string;
//  Translation: TLocalizerTranslation;
  TranslationStatus: TTranslationStatus;
  s: string;
begin
  if (Progress <> nil) then
    Progress.UpdateMessage(sProgressProjectLoad);

  XML := TXMLDocument.Create(nil);
  XML.Options := XML.Options + [doAttrNull];
  XML.ParseOptions := XML.ParseOptions + [poPreserveWhiteSpace];
  XML.LoadFromStream(Stream);

  RootNode := XML.ChildNodes[sLocalizationFileformatRoot];
  if (RootNode = nil) then
    raise ELocalizationPersistence.CreateFmt('Malformed project file. Root element not found: %s', [sLocalizationFileformatRoot]);

  ProjectNode := RootNode.ChildNodes['project'];
  if (ProjectNode = nil) then
    raise ELocalizationPersistence.CreateFmt('Malformed project file. Project element not found: %s', ['project']);

  Language := nil;
  CachedLanguage := '';

  Project.BeginUpdate;
  try
    Project.Clear;

    Project.SourceFilename := VarToStr(ProjectNode.Attributes['sourcefile']);
    if (not Project.SourceFilename.IsEmpty) and (TPath.GetExtension(Project.SourceFilename).IsEmpty) then
      Project.SourceFilename := Project.SourceFilename + '.exe';

    // UI will handle if the symbol file doesn't exist
    Project.StringSymbolFilename := VarToStr(ProjectNode.Attributes['stringsymbolfile']);

    Project.SourceLanguageID := StrToIntDef(VarToStr(ProjectNode.Attributes['language']), 0);

    LanguagesNode := ProjectNode.ChildNodes.FindNode('targetlanguages');
    if (LanguagesNode <> nil) then
      LanguageNode := LanguagesNode.ChildNodes.First
    else
      LanguageNode := nil;

    // Precreate target languages.
    // This ensures that they are present in the language list even if there are no translations for them yet.
    while (LanguageNode <> nil) do
    begin
      if (LanguageNode.NodeName = 'language') then
      begin
        s := VarToStr(LanguageNode.Attributes['language']);
        if (Language = nil) or (s <> CachedLanguage) then
          Language := Project.TranslationLanguages.Add(StrToIntDef(s, 0));
      end;
      LanguageNode := LanguageNode.NextSibling;
    end;

    ModulesNode := ProjectNode.ChildNodes.FindNode('modules');
    if (ModulesNode = nil) then
      exit;

    if (Progress <> nil) then
      Progress.Progress(psBegin, 0, ModulesNode.ChildNodes.Count, sProgressProjectReadModules);

    ModuleNode := ModulesNode.ChildNodes.First;
    while (ModuleNode <> nil) do
    begin
      if (Progress <> nil) then
        Progress.AdvanceProgress;

      if (ModuleNode.NodeName = 'module') then
      begin
        Module := Project.AddModule(VarToStr(ModuleNode.Attributes['name']));
        Module.Kind := StringToModuleKind(VarToStr(ModuleNode.Attributes['type']));
        StringToItemState(Module, VarToStr(ModuleNode.Attributes['state']));
        Module.Status := StringToItemStatus(VarToStr(ModuleNode.Attributes['status']));

        ItemsNode := ModuleNode.ChildNodes.FindNode('items');
        if (ItemsNode <> nil) then
        begin
          ItemNode := ItemsNode.ChildNodes.First;
          while (ItemNode <> nil) do
          begin
            if (ItemNode.NodeName = 'item') then
            begin
              Item := Module.AddItem(VarToStr(ItemNode.Attributes['name']), VarToStr(ItemNode.Attributes['type']));
              Item.ResourceID := StrToIntDef(VarToStr(ItemNode.Attributes['id']), 0);
              StringToItemState(Item, VarToStr(ItemNode.Attributes['state']));
              Item.Status := StringToItemStatus(VarToStr(ItemNode.Attributes['status']));

              PropsNode := ItemNode.ChildNodes.FindNode('properties');
              if (PropsNode <> nil) then
              begin
                PropNode := PropsNode.ChildNodes.First;
                while (PropNode <> nil) do
                begin
                  if (PropNode.NodeName = 'property') then
                  begin
                    s := VarToStr(PropNode.ChildValues['value']);
                    // s := s.Replace(#10, #13);
                    s := DecodeString(s);
                    Prop := Item.AddProperty(VarToStr(PropNode.Attributes['name']), s);
                    StringToItemState(Prop, VarToStr(PropNode.Attributes['state']));
                    Prop.Status := StringToItemStatus(VarToStr(PropNode.Attributes['status']));
                    Prop.Flags := StringToPropFlags(VarToStr(PropNode.Attributes['flags']));

                    XlatsNode := PropNode.ChildNodes.FindNode('translations');
                    if (XlatsNode <> nil) then
                    begin
                      XlatNode := XlatsNode.ChildNodes.First;
                      while (XlatNode <> nil) do
                      begin
                        if (XlatNode.NodeName = 'translation') then
                        begin
                          s := VarToStr(XlatNode.Attributes['language']);
                          if (Language = nil) or (s <> CachedLanguage) then
                            Language := Project.TranslationLanguages.Add(StrToIntDef(s, 0));
                          TranslationStatus := StringToTranslationStatus(VarToStr(XlatNode.Attributes['status']));
                          s := XlatNode.Text;
                          // s := s.Replace(#10, #13);
                          s := DecodeString(s);
                          {Translation :=} Prop.Translations.AddOrUpdateTranslation(Language, s, TranslationStatus);
                        end;
                        XlatNode := XlatNode.NextSibling;
                      end;
                    end;
                  end;
                  PropNode := PropNode.NextSibling;
                end;
              end;
            end;
            ItemNode := ItemNode.NextSibling;
          end;
        end;
      end;
      ModuleNode := ModuleNode.NextSibling;
    end;
    if (Progress <> nil) then
      Progress.Progress(psEnd, 1, 1);
  finally
    Project.EndUpdate;
  end;
end;

// -----------------------------------------------------------------------------

class procedure TLocalizationProjectFiler.SaveToFile(Project: TLocalizerProject; const Filename: string; const Progress: IProgress);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(Filename, fmCreate);
  try
    SaveToStream(Project, Stream, Progress);
  finally
    Stream.Free;
  end;
end;

// -----------------------------------------------------------------------------

class procedure TLocalizationProjectFiler.SaveToStream(Project: TLocalizerProject; Stream: TStream; const Progress: IProgress);

  procedure WriteItemState(const Node: IXMLNode; Item: TCustomLocalizerItem);
  var
    State: TLocalizerItemState;
    s: string;
  begin
    if (Item.InheritParentState) or (Item.State = []) then
      Exit;
    s := '';
    for State in Item.State do
    begin
      if (s <> '') then
        s := s + ',';
      s := s + sItemState[State];
    end;
    Node.Attributes['state'] := s;
  end;

  procedure WriteItemStatus(const Node: IXMLNode; Item: TCustomLocalizerItem);
  begin
    if (Item.Status <> ItemStatusTranslate) then
      Node.Attributes['status'] := sItemStatus[Item.Status];
  end;

  procedure WriteItemName(const Node: IXMLNode; Item: TCustomLocalizerItem);
  begin
    if (not Item.Name.IsEmpty) then
      Node.Attributes['name'] := Item.Name;
  end;

  procedure WriteItemID(const Node: IXMLNode; ID: integer);
  begin
    // We no longer save the ID - It isn't used for anything
    (*
    if (ID <> 0) and (ID <> -1) then
      Node.Attributes['id'] := ID;
    *)
  end;

  procedure WritePropFlags(const Node: IXMLNode; Prop: TLocalizerProperty);
  var
    s: string;
    Flag: TPropertyFlag;
  begin
    if (Prop.Flags = []) then
      Exit;
    s := '';
    for Flag in Prop.Flags do
      if (Flag in [FlagBookmark0..FlagBookmark9]) then
        s := s + Char(Ord('0') + Ord(Flag) - Ord(FlagBookmark0))
      else
        s := s + Char(Ord('A') + Ord(Flag) - Ord(FlagBookmarkA));
    Node.Attributes['flags'] := s;
  end;

var
  XML: IXMLDocument;
  RootNode, Node: IXMLNode;
  ProjectNode: IXMLNode;
  LanguagesNode, LanguageNode: IXMLNode;
  ModulesNode, ModuleNode: IXMLNode;
  ItemsNode, ItemNode: IXMLNode;
  PropsNode, PropNode: IXMLNode;
  XlatsNode, XlatNode: IXMLNode;
  Module: TLocalizerModule;
  Item: TLocalizerItem;
  Prop: TLocalizerProperty;
  i: integer;
begin
  XML := TXMLDocument.Create(nil);
  XML.Options := [doNodeAutoIndent];
  XML.Active := True;

  RootNode := XML.AddChild(sLocalizationFileformatRoot);

  Node := RootNode.AddChild('meta');
  Node.AddChild('version').Text := '1';
  Node.AddChild('created').Text := DateToISO8601(Now, False);
  Node.AddChild('tool').Text := TPath.GetFileNameWithoutExtension(ParamStr(0));
  Node.AddChild('toolversion').Text := TVersionInfo.FileVersionString(ParamStr(0));

  ProjectNode := RootNode.AddChild('project');
  // Paths are assumed to be absolute or relative to the project file
  ProjectNode.Attributes['sourcefile'] := Project.SourceFilename;
  ProjectNode.Attributes['stringsymbolfile'] := Project.StringSymbolFilename;
  ProjectNode.Attributes['language'] := Project.SourceLanguageID;

  LanguagesNode := ProjectNode.AddChild('targetlanguages');
  for i := 0 to Project.TranslationLanguages.Count-1 do
  begin
    LanguageNode := LanguagesNode.AddChild('language');
    LanguageNode.Attributes['language'] := Project.TranslationLanguages[i].LanguageID;
    LanguageNode.Attributes['translated'] := Project.TranslationLanguages[i].TranslatedCount;
  end;

  Node := RootNode.AddChild('options');
  // Store the stringlist handling setting that was used with the project
  Node.AddChild('stringlisthandling').Text := IntToStr(Ord(StringListHandling));

  ModulesNode := ProjectNode.AddChild('modules');

  for Module in Project.Modules.Values do
  begin
    ModuleNode := ModulesNode.AddChild('module');
    WriteItemName(ModuleNode, Module);
    ModuleNode.Attributes['type'] := sModuleKind[Module.Kind];
    WriteItemState(ModuleNode, Module);
    WriteItemStatus(ModuleNode, Module);

    ItemsNode := ModuleNode.AddChild('items');

    for Item in Module.Items.Values do
    begin
      ItemNode := ItemsNode.AddChild('item');
      WriteItemName(ItemNode, Item);
      WriteItemID(ItemNode, Item.ResourceID);
      if (Item.TypeName <> '') then
        ItemNode.Attributes['type'] := Item.TypeName;
      WriteItemState(ItemNode, Item);
      WriteItemStatus(ItemNode, Item);

      PropsNode := ItemNode.AddChild('properties');

      for Prop in Item.Properties.Values do
      begin
        PropNode := PropsNode.AddChild('property');
        WriteItemName(PropNode, Prop);
        WriteItemState(PropNode, Prop);
        WriteItemStatus(PropNode, Prop);
        WritePropFlags(PropNode, Prop);

        PropNode.AddChild('value').Text := EncodeString(Prop.Value);

        XlatsNode := nil;
        Prop.Traverse(
          function(Prop: TLocalizerProperty; Translation: TLocalizerTranslation): boolean
          begin
            if (XlatsNode = nil) then
              XlatsNode :=  PropNode.AddChild('translations');

            XlatNode := XlatsNode.AddChild('translation');
            XlatNode.Attributes['language'] := Translation.Language.LanguageID;
            if (Translation.Status <> tStatusTranslated) then
              XlatNode.Attributes['status'] := sTranslationStatus[Translation.Status];
            XlatNode.Text := EncodeString(Translation.Value);
            Result := True;
          end);
      end;
    end;
  end;

  XML.SaveToStream(Stream);
end;

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

end.
