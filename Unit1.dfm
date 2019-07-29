object Form1: TForm1
  Left = 494
  Top = 189
  Width = 647
  Height = 515
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 120
  TextHeight = 16
  object Button1: TButton
    Left = 69
    Top = 20
    Width = 92
    Height = 30
    Caption = 'READ'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Memo1: TMemo
    Left = 69
    Top = 59
    Width = 523
    Height = 385
    Lines.Strings = (
      'Memo1')
    TabOrder = 1
  end
  object ProgressBar1: TProgressBar
    Left = 69
    Top = 453
    Width = 523
    Height = 21
    TabOrder = 2
  end
  object Button2: TButton
    Left = 305
    Top = 20
    Width = 93
    Height = 30
    Caption = 'VDI->RAW'
    TabOrder = 3
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 502
    Top = 20
    Width = 92
    Height = 30
    Caption = 'Cancel'
    TabOrder = 4
    OnClick = Button3Click
  end
  object OpenDialog1: TOpenDialog
    Left = 208
    Top = 16
  end
end
