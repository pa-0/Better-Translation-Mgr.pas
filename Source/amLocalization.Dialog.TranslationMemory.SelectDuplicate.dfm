inherited FormSelectDuplicate: TFormSelectDuplicate
  ActiveControl = ComboBoxAction
  Caption = 'Duplicate translations found'
  ClientHeight = 355
  ClientWidth = 502
  ExplicitWidth = 508
  ExplicitHeight = 383
  PixelsPerInch = 96
  TextHeight = 13
  inherited LayoutControlButtons: TdxLayoutControl
    Top = 307
    Width = 502
    ExplicitTop = 307
    ExplicitWidth = 502
    inherited ButtonOK: TcxButton
      Left = 335
      ExplicitLeft = 335
    end
    inherited ButtonCancel: TcxButton
      Left = 416
      ExplicitLeft = 416
    end
  end
  inherited LayoutControlHeader: TdxLayoutControl
    Width = 502
    ExplicitWidth = 502
    inherited LabelHeader: TcxLabel
      Caption = 'Select the translation to use'
      ExplicitWidth = 480
      Width = 480
    end
  end
  inherited PanelMain: TPanel
    Width = 502
    Height = 268
    ExplicitTop = 39
    ExplicitWidth = 502
    ExplicitHeight = 268
    inherited LayoutControl: TdxLayoutControl
      Width = 486
      Height = 256
      ExplicitLeft = 8
      ExplicitWidth = 486
      ExplicitHeight = 256
      object LabelSourceValue: TLabel [0]
        Left = 73
        Top = 69
        Width = 407
        Height = 14
        AutoSize = False
        Caption = '-'
        EllipsisPosition = epEndEllipsis
        ShowAccelChar = False
        Transparent = True
        Layout = tlCenter
      end
      object ListViewDuplicates: TcxListView [1]
        Left = 73
        Top = 89
        Width = 407
        Height = 136
        ColumnClick = False
        Columns = <
          item
            AutoSize = True
          end>
        HideSelection = False
        ReadOnly = True
        RowSelect = True
        ShowColumnHeaders = False
        TabOrder = 2
        ViewStyle = vsReport
        OnDblClick = ListViewDuplicatesDblClick
      end
      object CheckBoxAll: TcxCheckBox [2]
        Left = 287
        Top = 6
        Caption = '&Do this for all conflicts'
        Enabled = False
        Properties.OnChange = CheckBoxAllPropertiesChange
        Style.HotTrack = False
        TabOrder = 1
      end
      object ComboBoxAction: TcxComboBox [3]
        Left = 73
        Top = 6
        Properties.DropDownListStyle = lsFixedList
        Properties.Items.Strings = (
          'Use the translation I select'
          'Use first available translation'
          'Skip value')
        Properties.OnChange = ComboBoxActionPropertiesChange
        Style.HotTrack = False
        TabOrder = 0
        Text = 'Use the translation I select'
        Width = 192
      end
      object LabelContext: TLabel [4]
        Left = 73
        Top = 49
        Width = 407
        Height = 14
        AutoSize = False
        Caption = '-'
        EllipsisPosition = epPathEllipsis
        ShowAccelChar = False
        Transparent = True
        Layout = tlCenter
      end
      object CheckBoxApplyToIdentical: TcxCheckBox [5]
        Left = 73
        Top = 231
        Caption = '&Use this translation for identical conflicts'
        Style.HotTrack = False
        TabOrder = 3
      end
      inherited LayoutControlGroup_Root: TdxLayoutGroup
        AlignVert = avClient
        ItemIndex = 5
      end
      object LayoutItemSourceValue: TdxLayoutItem
        Parent = LayoutControlGroup_Root
        CaptionOptions.Text = 'Source text:'
        Control = LabelSourceValue
        ControlOptions.OriginalHeight = 14
        ControlOptions.OriginalWidth = 46
        ControlOptions.ShowBorder = False
        Index = 3
      end
      object LayoutItemTranslationList: TdxLayoutItem
        Parent = LayoutControlGroup_Root
        AlignVert = avClient
        CaptionOptions.AlignVert = tavTop
        CaptionOptions.Text = '&Translations:'
        Control = ListViewDuplicates
        ControlOptions.OriginalHeight = 156
        ControlOptions.OriginalWidth = 121
        ControlOptions.ShowBorder = False
        Index = 4
      end
      object dxLayoutItem5: TdxLayoutItem
        Parent = dxLayoutGroup2
        CaptionOptions.Text = 'cxCheckBox1'
        CaptionOptions.Visible = False
        Control = CheckBoxAll
        ControlOptions.OriginalHeight = 19
        ControlOptions.OriginalWidth = 126
        ControlOptions.ShowBorder = False
        Enabled = False
        Index = 2
      end
      object dxLayoutItem6: TdxLayoutItem
        Parent = dxLayoutGroup2
        CaptionOptions.Text = '&Action:'
        Control = ComboBoxAction
        ControlOptions.OriginalHeight = 21
        ControlOptions.OriginalWidth = 192
        ControlOptions.ShowBorder = False
        Index = 0
      end
      object dxLayoutEmptySpaceItem2: TdxLayoutEmptySpaceItem
        Parent = LayoutControlGroup_Root
        CaptionOptions.Text = 'Empty Space Item'
        SizeOptions.Height = 10
        SizeOptions.Width = 10
        Index = 1
      end
      object dxLayoutGroup2: TdxLayoutGroup
        Parent = LayoutControlGroup_Root
        CaptionOptions.Visible = False
        ButtonOptions.Buttons = <>
        ItemIndex = 1
        LayoutDirection = ldHorizontal
        ShowBorder = False
        Index = 0
      end
      object dxLayoutEmptySpaceItem3: TdxLayoutEmptySpaceItem
        Parent = dxLayoutGroup2
        CaptionOptions.Text = 'Empty Space Item'
        SizeOptions.Height = 10
        SizeOptions.Width = 10
        Index = 1
      end
      object LayoutItemContext: TdxLayoutItem
        Parent = LayoutControlGroup_Root
        CaptionOptions.Text = 'Context:'
        Control = LabelContext
        ControlOptions.OriginalHeight = 14
        ControlOptions.OriginalWidth = 8
        ControlOptions.ShowBorder = False
        Index = 2
      end
      object dxLayoutItem8: TdxLayoutItem
        Parent = LayoutControlGroup_Root
        CaptionOptions.Text = ' '
        Control = CheckBoxApplyToIdentical
        ControlOptions.OriginalHeight = 19
        ControlOptions.OriginalWidth = 85
        ControlOptions.ShowBorder = False
        Index = 5
      end
    end
  end
  inherited ActionList: TActionList
    inherited ActionOK: TAction
      OnUpdate = ActionOKUpdate
    end
  end
end
