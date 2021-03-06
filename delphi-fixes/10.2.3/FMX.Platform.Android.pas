﻿(* ****************************************************** *)
(*　　　　　　　　　　　　　　　　　　　　　　　　　　　　*)
(*　　　　修改：爱吃猪头肉 & Flying Wang 2013-09-19　　　 *)
(*　　　　　　　　上面的版权声明请不要移除。　　　　　　　*)
(*　　　　　　　　　　　　　　　　　　　　　　　　　　　　*)
(*　　　    　　　　　禁止发布到城通网盘。　　　　  　　　*)
(*　　　　　　　　　　　　　　　　　　　　　　　　　　　　*)
(*　仅支持 RAD10.2.3(10.2 Release 3)，其他版本请自行修改　*)
(*　　　　　　　　　　　　　　　　　　　　　　　　　　　　*)
(* ****************************************************** *)
//https://quality.embarcadero.com/browse/RSP-18043

{*******************************************************}
{                                                       }
{              Delphi FireMonkey Platform               }
{                                                       }
{ Copyright(c) 2011-2017 Embarcadero Technologies, Inc. }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

unit FMX.Platform.Android;

interface

{$SCOPEDENUMS ON}

uses
  System.Types, System.UITypes, System.Messaging, Androidapi.JNI.Embarcadero, FMX.Forms, FMX.Types, FMX.Types3D;

type

  TAndroidWindowHandle = class(TWindowHandle)
  strict private
    FTexture: TTexture;
    FBounds: TRectF;
    [Weak] FForm: TCommonCustomForm;
    FNeedsUpdate: Boolean;
  private
    procedure SetBounds(const Value: TRectF);
    procedure SetNeedsUpdate(const Value: Boolean);
    function GetIsPopup: Boolean;
    function GetBounds: TRectF;
  protected
    function GetScale: Single; override;
  public
    constructor Create(const AForm: TCommonCustomForm);
    procedure CreateTexture;
    procedure DestroyTexture;
    function RequiresComposition: Boolean;
    property Bounds: TRectF read GetBounds write SetBounds;
    property Form: TCommonCustomForm read FForm;
    property Texture: TTexture read FTexture;
    property NeedsUpdate: Boolean read FNeedsUpdate write SetNeedsUpdate;
    property IsPopup: Boolean read GetIsPopup;
  end;

  { Broadcast messages: Taking images }

  TMessageCancelReceivingImage = class(TMessage<Integer>);

  TMessageReceivedImagePath = class(TMessage<string>)
  public
    RequestCode: Integer;
  end;

function WindowHandleToPlatform(const AHandle: TWindowHandle): TAndroidWindowHandle;
function MainActivity: JFMXNativeActivity;

function ConvertPixelToPoint(const P: TPointF): TPointF;
function ConvertPointToPixel(const P: TPointF): TPointF;

procedure RegisterCorePlatformServices;
procedure UnregisterCorePlatformServices;

//Fix or Add By Flying Wang
var
  /// <summary>
  ///   获取当前状态条高度（非 fmx 高度，像素高度）
  /// </summary>
  CurrStatusBarPixelHeight: Single = 20;
  /// <summary>
  ///   获取当前状态条高度（fmx 高度）
  /// </summary>
  CurrStatusBarFmxHeight: Single = 10;
  /// <summary>
  ///   强行要求不计算状态条的高度。
  /// </summary>
  ForceNoStatusBar: Boolean = False;
  /// <summary>
  ///   在单击输入框的时候，不显示粘贴按钮。
  /// </summary>
  NoPasteWhenSingleTap: Boolean = False;


//Fix or Add By Flying Wang
/// <summary>
///   获取 StatusBar 的像素高
/// </summary>
function GetStatusBarPixelHeight: Integer;
function GetStatusBarHeight: Single;

/// <summary>
///   获取 NavigationBar 的像素高
/// </summary>
function GetNavigationBarPixelHeight: Integer;
function GetNavigationBarHeight: Single;

//Fix or Add By Flying Wang
procedure ForceUpdateScreenSize;

implementation

uses
  System.Classes, System.SysUtils, System.Math, System.Math.Vectors, System.Generics.Collections, System.Character,
  System.RTLConsts, System.Devices, System.Rtti, System.UIConsts,
  Androidapi.Input, Androidapi.Jni.JavaTypes, Androidapi.Egl, Androidapi.Gles2, Androidapi.JNI.Widget, Androidapi.Keycodes,
  Androidapi.NativeWindow, Androidapi.NativeActivity, Androidapi.AppGlue, Androidapi.JNIBridge, Androidapi.Helpers,
  Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.App, Androidapi.JNI.Os,
  FMX.KeyMapping, FMX.Helpers.Android, FMX.Canvas.GPU, FMX.Controls, FMX.Controls.Android, FMX.Materials.Canvas,
  FMX.Gestures, FMX.VirtualKeyboard,  FMX.Consts, FMX.Text, FMX.Graphics, FMX.TextLayout, FMX.Maps, FMX.Platform,
  FMX.Presentation.Style, FMX.Ani, FMX.Context.GLES.Android, FMX.Graphics.Android,
  FMX.MultiTouch.Android, FMX.VirtualKeyboard.Android, FMX.Gestures.Android, FMX.Dialogs.Android,
  FMX.Platform.Timer.Android, FMX.Platform.Device.Android, FMX.Platform.Logger.Android, FMX.Platform.SaveState.Android,
  FMX.Platform.Screen.Android, FMX.Platform.Metrics.Android;

//Fix or Add By Flying Wang
function GetStatusBarPixelHeight: Integer;
var
  resourceId: Integer;
begin
//http://blog.csdn.net/u012764110/article/details/49783465
  Result := 20;
  try
    resourceId := TAndroidHelper.Context.getResources.getIdentifier(
      StringToJString('status_bar_height'),
      StringToJString('dimen'),
      StringToJString('android'));
    if resourceId <> 0 then
      Result := TAndroidHelper.Context.getResources.getDimensionPixelSize(resourceId);
  except
    Result := 20;
  end;
end;

function GetStatusBarHeight: Single;
var
  TempP: TPointF;
begin
  TempP.X := 0;
  TempP.Y := GetStatusBarPixelHeight;
  Result := ConvertPixelToPoint(TempP).Y;
end;

//Fix or Add By Flying Wang
type
  JSystemPropertiesClass = interface(IJavaClass)
    ['{C14AB573-CC6F-4087-A1FB-047E92F8E718}']
    function get(name: JString): JString; cdecl;
  end;

  [JavaSignature('android/os/SystemProperties')]
  JSystemProperties = interface(IJavaInstance)
    ['{58A4A7BF-80D0-4FF8-9CF3-F94123C8EEB7}']
  end;
  TJSystemProperties = class(TJavaGenericImport<JSystemPropertiesClass, JSystemProperties>) end;

//Fix or Add By Flying Wang
function GetNavigationBarPixelHeight: Integer;
var
  //oObj: JSystemProperties;
  oStr: JString;
  resourceId: Integer;
  AStr: string;
  HasNavigationBar: Boolean;
begin
//http://blog.csdn.net/u012764110/article/details/49783465
//  Result := 24;
  HasNavigationBar := False;
  try
    resourceId := TAndroidHelper.Context.getResources.getIdentifier(
      StringToJString('config_showNavigationBar'),
      StringToJString('bool'),
      StringToJString('android'));
    if (resourceId <> 0) then
    begin
      Result := 0;
      HasNavigationBar := TAndroidHelper.Context.getResources.getBoolean(resourceId);
      AStr := '';
      try
        //http://blog.csdn.net/lgaojiantong/article/details/42874529
        oStr := TJSystemProperties.JavaClass.get(StringToJString('qemu.hw.mainkeys'));
        if oStr <> nil then
          AStr := JStringToString(oStr).Trim;
      except
        AStr := '';
      end;
      if AStr <> '' then
      begin
        if AStr = '0' then
        begin
          HasNavigationBar := True;
        end
        else if AStr = '1' then
        begin
          HasNavigationBar := False;
        end
        else
        begin
          if TryStrToBool(AStr, HasNavigationBar) then
          begin
            HasNavigationBar := not HasNavigationBar;
          end;
        end;
      end;
      if HasNavigationBar then
      begin
        resourceId := TAndroidHelper.Context.getResources.getIdentifier(
          StringToJString('navigation_bar_height'),
          StringToJString('dimen'),
          StringToJString('android'));
        if resourceId <> 0 then
          Result := TAndroidHelper.Context.getResources.getDimensionPixelSize(resourceId);
      end;
    end
    else
    begin
      Result := 0;
    end;
  except
    Result := 0;
  end;
end;

function GetNavigationBarHeight: Single;
var
  TempP: TPointF;
begin
  TempP.X := 0;
  TempP.Y := GetNavigationBarPixelHeight;
  Result := ConvertPixelToPoint(TempP).Y;
end;
//fix end.

type

  TFMXNativeActivityListener = class (TJavaLocal, JOnActivityListener)
  public
    procedure onCancelReceiveImage(ARequestCode: Integer); cdecl;
    procedure onReceiveImagePath(ARequestCode: Integer; AFileName: JString); cdecl;
    procedure onReceiveNotification(P1: JIntent); cdecl;
    procedure onReceiveResult(ARequestCode, AResultCode: Integer; AResultObject: JIntent); cdecl;
  end;

  TCopyButtonClickListener = class(TJavaLocal, JView_OnClickListener)
  public
    procedure onClick(P1: JView); cdecl;
  end;

  TCutButtonClickListener = class(TJavaLocal, JView_OnClickListener)
  public
    procedure onClick(P1: JView); cdecl;
  end;

  TPasteButtonClickListener = class(TJavaLocal, JView_OnClickListener)
  public
    procedure onClick(P1: JView); cdecl;
  end;

  TTextServiceAndroid = class;

  TWindowManager = class(TInterfacedObject, IFreeNotification, IFMXWindowService)
  //Fix By 10.2.1
  public const
    DefaultRenderTimestep = 16; // ms ~ 60FPS
    MinRenderTimestep = 5; // Minimal timer step without app freezing
  private
    FLastRenderTime: Double;
    FRenderTimer: TFmxHandle;
    { Rendering }
    procedure CreateRenderTimer;
    procedure DestroyRenderTimer;
    procedure RenderProc;
    function GetRenderTimestep: Integer;
  //Fix By 10.2.1 end.
  public const
    HidePasteMenuDelay = 2500;
  public type
    TContextMenuItem = (Copy, Cut, Paste);
    TContextMenuItems = set of TContextMenuItem;
  public const
    AllContextMenuItems = [TContextMenuItem.Copy, TContextMenuItem.Cut, TContextMenuItem.Paste];
  private type
    TRenderRunnable = class(TJavaLocal, JRunnable)
    private class var
      [weak] FManager: TWindowManager;
      FMainHandler: JHandler;
    private
      class function GetMainHandler: JHandler; static;
    public
      constructor Create(const AManager: TWindowManager);
      procedure run; cdecl;
      class property MainHandler: JHandler read GetMainHandler;
    end;
  private class var
    FRenderRunnable: TRenderRunnable;
  private
    class var FInstance: TWindowManager;
    class function GetInstance: TWindowManager; static;
  private
    FRenderLock: TObject;
    FTimerService: IFMXTimerService;
    FVirtualKeyboard: IFMXVirtualKeyboardService;
    FWindows: TList<TAndroidWindowHandle>;
    FVisibleStack: TStack<TAndroidWindowHandle>;
    [Weak] FGestureControl: TComponent;
    [Weak] FMouseDownControl: TControl;
    FNeedsRender: Boolean;
    FPause: Boolean;
    FScale: Single;
    FContentRect: TRect;
    FStatusBarHeight: Integer;
    //Text editing
    FFocusedControl: IControl;
    FContextMenuPopup: JPopupWindow;
    FContextMenuPopupSize: TSize;
    FContextMenuLayout: JLinearLayout;
    FContextButtonsLayout: JLinearLayout;
    FCopyButton: JButton;
    FCopyClickListener: TCopyButtonClickListener;
    FCutButton: JButton;
    FCutClickListener: TCutButtonClickListener;
    FPasteButton: JButton;
    FPasteClickListener: TPasteButtonClickListener;
    FContextMenuVisible: Boolean;
    [Weak] FCapturedWindow: TAndroidWindowHandle;
    FSelectionInProgress: Boolean;
    FPasteMenuTimer: TFmxHandle;
    FMultiTouchManager: TMultiTouchManagerAndroid;
    FContext: TContext3D;
    FIsFirstSingleTap: Boolean;
    procedure SetContentRect(const Value: TRect);
    procedure SetPause(const Value: Boolean);
    function GetMultiTouchManager: TMultiTouchManagerAndroid;
    procedure UpdateFormSizes;
    procedure ShowContextMenu(const ItemsToShow: TContextMenuItems = AllContextMenuItems);
    procedure DoShowContextMenu;
    procedure VKStateHandler(const Sender: TObject; const M: TMessage);
    procedure HideContextMenu;
    { Context Menu }
    procedure CreatePasteMenuTimer;
    procedure DestroyPasteMenuTimer;
    procedure PasteMenuTimerCall;
    { Popup }
    procedure PrepareClosePopups(const SaveForm: TAndroidWindowHandle);
    procedure ClosePopups;
    { Rendering }
    procedure PostRenderRunnable;
    procedure ReleaseRenderRunnable;
    { IFreeNotification }
    procedure FreeNotification(AObject: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    function IsPopupForm(const AForm: TCommonCustomForm): Boolean;
    procedure InitWindow;
    procedure TermWindow;
    procedure GainedFocus;
    { IFMXWindowService }
    function FindForm(const AHandle: TWindowHandle): TCommonCustomForm;
    function CreateWindow(const AForm: TCommonCustomForm): TWindowHandle;
    procedure DestroyWindow(const AForm: TCommonCustomForm);
    procedure ReleaseWindow(const AForm: TCommonCustomForm);
    procedure ShowWindow(const AForm: TCommonCustomForm);
    procedure HideWindow(const AForm: TCommonCustomForm);
    procedure BringToFront(const AForm: TCommonCustomForm); overload;
    procedure SendToBack(const AForm: TCommonCustomForm); overload;
    procedure Activate(const AForm: TCommonCustomForm);
    function ShowWindowModal(const AForm: TCommonCustomForm): TModalResult;
    function CanShowModal: Boolean;
    procedure InvalidateWindowRect(const AForm: TCommonCustomForm; R: TRectF);
    procedure InvalidateImmediately(const AForm: TCommonCustomForm);
    procedure SetWindowRect(const AForm: TCommonCustomForm; ARect: TRectF);
    function GetWindowRect(const AForm: TCommonCustomForm): TRectF;
    function GetClientSize(const AForm: TCommonCustomForm): TPointF;
    procedure SetClientSize(const AForm: TCommonCustomForm; const ASize: TPointF);
    procedure SetWindowCaption(const AForm: TCommonCustomForm; const ACaption: string);
    procedure SetCapture(const AForm: TCommonCustomForm);
    procedure SetWindowState(const AForm: TCommonCustomForm; const AState: TWindowState);
    procedure ReleaseCapture(const AForm: TCommonCustomForm);
    function ClientToScreen(const AForm: TCommonCustomForm; const Point: TPointF): TPointF;
    function ScreenToClient(const AForm: TCommonCustomForm; const Point: TPointF): TPointF; overload;
    function GetWindowScale(const AForm: TCommonCustomForm): Single;

    procedure BeginSelection;
    procedure EndSelection;
    procedure SetNeedsRender;
    function RenderIfNeeds: Boolean;
    procedure RenderImmediately;
    procedure Render;
    procedure BringToFront(const AHandle: TAndroidWindowHandle); overload;
    procedure SendToBack(const AHandle: TAndroidWindowHandle); overload;
    procedure AddWindow(const AHandle: TAndroidWindowHandle);
    procedure RemoveWindow(const AHandle: TAndroidWindowHandle);
    function AlignToPixel(const Value: Single): Single; inline;
    function FindWindowByPoint(X, Y: Single): TAndroidWindowHandle;
    function FindTopWindow: TAndroidWindowHandle;
    function FindTopWindowForTextInput: TAndroidWindowHandle;
    function SendCMGestureMessage(AEventInfo: TGestureEventInfo): Boolean;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure MouseMove(Shift: TShiftState; X, Y: Single);
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single; DoCLick: Boolean = True);
    procedure KeyDown(var Key: Word; var KeyChar: System.WideChar; Shift: TShiftState);
    procedure KeyUp(var Key: Word; var KeyChar: System.WideChar; Shift: TShiftState; KeyDownHandled: Boolean);
    procedure MultiTouch(const Touches: TTouches; const Action: TTouchAction; const AEnabledGestures: TInteractiveGestures = []);
    function PixelToPoint(const P: TPointF): TPointF;
    function PointToPixel(const P: TPointF): TPointF;
    function ScreenToClient(const Handle: TAndroidWindowHandle; const Point: TPointF): TPointF; overload;
    procedure SingleTap;
    function TextGetService: TTextServiceAndroid;
    function TextGetActions: ITextActions;
    procedure TextResetSelection;
    function TextReadOnly: Boolean;
    procedure SetFocusedControl(const Control: IControl);
  public
    property ContentRect: TRect read FContentRect write SetContentRect;
    property Windows: TList<TAndroidWindowHandle> read FWindows;
    property Pause: Boolean read FPause write SetPause;
    property Scale: Single read FScale;
    property StatusBarHeight: Integer read FStatusBarHeight;
    property MultiTouchManager: TMultiTouchManagerAndroid read GetMultiTouchManager;
    class property Current: TWindowManager read GetInstance;
  end;

  TAndroidMotionManager = class(TInterfacedObject, IFMXGestureRecognizersService, IFMXMouseService)
  private const
    DblTapDelay = 300; //delay between the 2 taps
    SingleTapDelay = 150;
    LongTapDuration = 500;
    LongTapMovement = 10; //10 pixels - use scale to transform to points to use on each device
  private type
    TMotionEvent = record
      Position: TPointF;
      EventAction: Int32;
      Shift: TShiftState;
    end;
    TMotionEvents = TList<TMotionEvent>;
  private
    { Gestures }
    FActiveInteractiveGestures: TInteractiveGestures;
    FEnabledInteractiveGestures: TInteractiveGestures;
    FMotionEvents: TMotionEvents;
    FDoubleTapTimer: TFmxHandle;
    FLongTapTimer: TFmxHandle;
    FSingleTapTimer: TFmxHandle;
    FDblClickFirstMouseUp: Boolean;
    FSingleTap: Boolean;
    FOldPoint1, FOldPoint2: TPointF;
    FRotationAngle: Single;
    FGestureEnded: Boolean;
    { Mouse }
    FMouseCoord: TPointF;
    FMouseDownCoordinates: TPointF;
    { Single Tap }
    procedure SingleTap;
    procedure CreateSingleTapTimer;
    procedure DestroySingleTapTimer;
    procedure SingleTapTimerCall;
    { Double Tap }
    procedure CreateDoubleTapTimer;
    procedure DestroyDoubleTapTimer;
    procedure DoubleTapTimerCall;
    { Long Tap }
    procedure CreateLongTapTimer;
    procedure DestroyLongTapTimer;
    procedure LongTapTimerCall;
    function GetLongTapAllowedMovement: Single;
    procedure HandleMultiTouch;
  protected
    function HandleAndroidMotionEvent(AEvent: PAInputEvent): Int32;
    function CreateGestureEventInfo(ASecondPointer: TPointF; const AGesture: TInteractiveGesture; const AGestureEnded: Boolean = False): TGestureEventInfo;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ProcessAndroidGestureEvents;
    procedure ProcessAndroidMouseEvents;
    { IFMXGestureRecognizersService }
    procedure AddRecognizer(const AGesture: TInteractiveGesture; const AForm: TCommonCustomForm);
    procedure RemoveRecognizer(const AGesture: TInteractiveGesture; const AForm: TCommonCustomForm);
    { IFMXMouseService }
    function GetMousePos: TPointF;
  end;

  TAndroidTextInputManager = class(TInterfacedObject, IFMXKeyMappingService, IFMXTextService)
  private
    FVirtualKeyboard: IFMXVirtualKeyboardService;
    FKeyMapping: TKeyMapping;
    FSkipEventQueue: TQueue<JKeyEvent>;
    FKeyCharacterMap: JKeyCharacterMap;
    FDownKey: Word;
    FDownKeyChar: System.WideChar;
    FKeyDownHandled: Boolean;
    FTextEditorProxy: JFMXTextEditorProxy;
    procedure SetKeyboardEventToSkip(event: JKeyEvent);
    function ObtainKeyCharacterMap(DeviceId: Integer): JKeyCharacterMap;
    function ShiftStateFromMetaState(const AMetaState: Integer): TShiftState;
  protected
    function HandleAndroidKeyEvent(AEvent: PAInputEvent): Int32;
  public
    constructor Create;
    destructor Destroy; override;
    { Android view for IME }
    function GetTextEditorProxy: JFmxTextEditorProxy;
    { IFMXTextService }
    function GetTextServiceClass: TTextServiceClass;
    { IFMXKeyMappingService }
    /// <summary>Registers a platform key as the given virtual key.</summary>
    function RegisterKeyMapping(const PlatformKey, VirtualKey: Word; const KeyKind: TKeyKind): Boolean;
    /// <summary>Unegisters a platform key as the given virtual key.</summary>
    function UnregisterKeyMapping(const PlatformKey: Word): Boolean;
    /// <summary>Obtains the virtual key from a given platform key.</summary>
    function PlatformKeyToVirtualKey(const PlatformKey: Word; var KeyKind: TKeyKind): Word;
    /// <summary>Obtains the platform key from a given virtual key.</summary>
    function VirtualKeyToPlatformKey(const VirtualKey: Word): Word;
  end;

  { TPlatformAndroid }

  TWakeMainThreadRunnable = class(TJavaLocal, JRunnable)
  public
    { JRunnable }
    procedure run; cdecl;
  end;

  TPlatformAndroid = class(TInterfacedObject, IFMXApplicationEventService, IFMXApplicationService)
  private const
    UndefinedOrientation = TScreenOrientation(-1);
  private type
    TMessageQueueIdleHandler = class(TJavaLocal, JMessageQueue_IdleHandler)
    private
      [Weak] FPlatform: TPlatformAndroid;
    public
      constructor Create(APlatform: TPlatformAndroid);
      function queueIdle: Boolean; cdecl;
    end;
  private
    { Core services }
    FTimerService: TAndroidTimerService;
    FDeviceServices: TAndroidDeviceServices;
    FLoggerService: TAndroidLoggerService;
    FSaveStateService: TAndroidSaveStateService;
    FScreenServices: TAndroidScreenServices;
    FGraphicServices: TAndroidGraphicsServices;
    FMetricsServices: TAndroidMetricsServices;
    FVirtualKeyboardService: TVirtualKeyboardAndroid;
    FWindowManager: TWindowManager;
    FMotionManager: TAndroidMotionManager;
    FTextInputManager: TAndroidTextInputManager;
    { Internal }
    FIdleHandler: TMessageQueueIdleHandler;
    FWakeMainThreadRunnable: TWakeMainThreadRunnable;
    FOnApplicationEvent: TApplicationEventHandler;
    FActivityListener: TFMXNativeActivityListener;
    FFirstRun: Boolean;
    FLastOrientation: TScreenOrientation;
    FRunning: Boolean;
    FTerminating: Boolean;
    FPreviousActivityCommands: TAndroidApplicationCommands;
    FTitle: string;
    procedure InternalProcessMessages;
    procedure CheckOrientationChange;
    procedure RegisterWakeMainThread;
    procedure UnregisterWakeMainThread;
    procedure WakeMainThread(Sender: TObject);
    procedure RegisterServices;
    procedure UnregisterServices;
    procedure BindAppGlueEvents;
    procedure UnbindAppGlueEvents;
  protected
    function HandleAndroidInputEvent(const App: TAndroidApplicationGlue; const AEvent: PAInputEvent): Int32;
    procedure HandleApplicationCommandEvent(const App: TAndroidApplicationGlue; const ACommand: TAndroidApplicationCommand);
    procedure HandleContentRectChanged(const App: TAndroidApplicationGlue; const ARect: TRect);
  public
    constructor Create;
    destructor Destroy; override;
    { IFMXApplicationService }
    procedure Run;
    function HandleMessage: Boolean;
    procedure WaitMessage;
    function GetDefaultTitle: string;
    function GetTitle: string;
    procedure SetTitle(const Value: string);
    function GetVersionString: string;
    function Running: Boolean;
    function Terminating: Boolean;
    procedure Terminate;
    { IFMXApplicationEventService }
    procedure SetApplicationEventHandler(AEventHandler: TApplicationEventHandler);
    function HandleApplicationEvent(AEvent: TApplicationEvent): Boolean;
  public
    property DeviceManager: TAndroidDeviceServices read FDeviceServices;
    property Logger: TAndroidLoggerService read FLoggerService;
    property Metrics: TAndroidMetricsServices read FMetricsServices;
    property MotionManager: TAndroidMotionManager read FMotionManager;
    property SaveStateManager: TAndroidSaveStateService read FSaveStateService;
    property ScreenManager: TAndroidScreenServices read FScreenServices;
    property TextInputManager: TAndroidTextInputManager read FTextInputManager;
    property TimerManager: TAndroidTimerService read FTimerService;
    property VirtualKeyboard: TVirtualKeyboardAndroid read FVirtualKeyboardService;
    property WindowManager: TWindowManager read FWindowManager;
  end;

  TFMXTextListener = class(TJavaLocal, JFMXTextListener)
  strict private
    [Weak] FTextService: TTextServiceAndroid;
  public
    constructor Create(const TextService: TTextServiceAndroid); overload;
    { JFMXTextListener }
    procedure onTextUpdated(text: JCharSequence; position: Integer); cdecl;
    procedure onComposingText(beginPosition: Integer; endPosition: Integer); cdecl;
    procedure onSkipKeyEvent(event: JKeyEvent); cdecl;
  end;

  TTextServiceAndroid = class(TTextService)
  private
    FCaretPosition: TPoint;
    FText : string;
    FImeMode: TImeMode;
    FTextView: JFmxTextEditorProxy;
    FTextListener: TFMXTextListener;
    FComposingBegin: Integer;
    FComposingEnd: Integer;
    FLines: TStrings;
    FInternalUpdate: Boolean;
    procedure UnpackText;
    procedure CalculateSelectionBounds(out SelectionStart, SelectionEnd: Integer);
    procedure HandleVK(const Sender: TObject; const M: TMessage);
    function IsFocused: Boolean;
  protected
    function GetText: string; override;
    procedure SetText(const Value: string); override;
    function GetCaretPostion: TPoint; override;
    procedure SetCaretPosition(const Value: TPoint); override;
    procedure SetMaxLength(const Value: Integer); override;
    procedure SetCharCase(const Value: TEditCharCase); override;
    procedure SetFilterChar(const Value: string); override;
  public
    procedure InternalUpdate;
    procedure InternalUpdateSelection;

    function CombinedText: string; override;
    function TargetClausePosition: TPoint; override;

    procedure EnterControl(const FormHandle: TWindowHandle); override;
    procedure ExitControl(const FormHandle: TWindowHandle); override;

    procedure DrawSingleLine(const  Canvas: TCanvas;
      const ARect: TRectF; const FirstVisibleChar: integer; const Font: TFont;
      const AOpacity: Single; const Flags: TFillTextFlags; const ATextAlign: TTextAlign;
      const AVTextAlign: TTextAlign = TTextAlign.Center;
      const AWordWrap: Boolean = False); overload;  override;

    procedure DrawSingleLine(const Canvas: TCanvas;
      const S: string;
      const ARect: TRectF;
      const Font: TFont;
      const AOpacity: Single; const Flags: TFillTextFlags; const ATextAlign: TTextAlign;
      const AVTextAlign: TTextAlign = TTextAlign.Center;
      const AWordWrap: Boolean = False); overload; override;

    function HasMarkedText: Boolean; override;

    function GetImeMode: TImeMode; override;
    procedure SetImeMode(const Value: TImeMode); override;

    { Selection }
    procedure BeginSelection; override;
    procedure EndSelection; override;
    procedure ProcessUpdate(const APos: Integer; AText: string);
    procedure PostProcessUpdate;
  public
    constructor Create(const Owner: IControl; SupportMultiLine: Boolean); override;
    destructor Destroy; override;
    procedure CutSelectedText;
    procedure CopySelectedText;
    procedure PasteText;
  end;

var
  PlatformAndroid: TPlatformAndroid;

//Fix or Add By Flying Wang
var
  TempForceUpdateScreenSize: Boolean = False;
procedure ForceUpdateScreenSize;
begin
  TempForceUpdateScreenSize := True;
  try
    TWindowManager.Current.SetContentRect(TWindowManager.Current.ContentRect);
  finally
    TempForceUpdateScreenSize := False;
  end;
end;

function WindowHandleToPlatform(const AHandle: TWindowHandle): TAndroidWindowHandle;
begin
  Result := TAndroidWindowHandle(AHandle);
end;

function MainActivity: JFMXNativeActivity;
begin
  if TAndroidApplicationGlue.Current <> nil then
    Result := TJFMXNativeActivity.Wrap(TAndroidApplicationGlue.Current.NativeActivity.clazz)
  else
    Result := nil;
end;

procedure RegisterCorePlatformServices;
begin
  PlatformAndroid := TPlatformAndroid.Create;
end;

procedure UnregisterCorePlatformServices;
begin
  FreeAndNil(PlatformAndroid);
end;

{ TCopyButtonClickListener }

procedure TCopyButtonClickListener.onClick(P1: JView);
var
  TextService: TTextServiceAndroid;
begin
  TextService := TWindowManager.Current.TextGetService;
  if TextService <> nil then
    TextService.CopySelectedText;
  TWindowManager.Current.TextResetSelection;
  TWindowManager.Current.HideContextMenu;
end;

{ TCutButtonClickListener }

procedure TCutButtonClickListener.onClick(P1: JView);
var
  TextService: TTextServiceAndroid;
begin
  TextService := TWindowManager.Current.TextGetService;
  if (TextService <> nil) and not TWindowManager.Current.TextReadOnly then
    TextService.CutSelectedText;
  TWindowManager.Current.TextResetSelection;
  TWindowManager.Current.HideContextMenu;
end;

{ TPasteButtonClickListener }

procedure TPasteButtonClickListener.onClick(P1: JView);
var
  TextService: TTextServiceAndroid;
begin
  TextService := TWindowManager.Current.TextGetService;
  if (TextService <> nil) and not TWindowManager.Current.TextReadOnly then
    TextService.PasteText;
  TWindowManager.Current.TextResetSelection;
  TWindowManager.Current.HideContextMenu;
end;

{ TWindowManager.TRenderRunnable }

constructor TWindowManager.TRenderRunnable.Create;
 begin
  inherited Create;
  FManager := AManager;
  MainHandler.post(Self);
end;

class function TWindowManager.TRenderRunnable.GetMainHandler: JHandler;
begin
  if FMainHandler = nil then
    FMainHandler := TJHandler.JavaClass.init(TJLooper.JavaClass.getMainLooper);
  Result := FMainHandler;
end;

procedure TWindowManager.TRenderRunnable.run;
begin
  FManager.RenderIfNeeds;
  FManager.ReleaseRenderRunnable;
end;

{ TWindowManager }

//fix by 10.2.1
procedure TWindowManager.CreateRenderTimer;
begin
  if FRenderTimer = 0 then
  begin
    FRenderTimer := FTimerService.CreateTimer(GetRenderTimestep, RenderProc);
  end;

end;

procedure TWindowManager.DestroyRenderTimer;
begin
  if FRenderTimer <> 0 then
  begin
    FTimerService.DestroyTimer(FRenderTimer);
    FRenderTimer := 0;
  end;
end;

procedure TWindowManager.RenderProc;
var
  SavedTime: Double;
begin
  SavedTime := FTimerService.GetTick;
  try
    RenderIfNeeds;
    DestroyRenderTimer;
  finally
    FLastRenderTime := FTimerService.GetTick - SavedTime;
  end;
end;

function TWindowManager.GetRenderTimestep: Integer;
begin
  Result := Max(MinRenderTimestep, DefaultRenderTimestep - Round(FLastRenderTime * 1000));
end;
//fix by 10.2.1 end.

constructor TWindowManager.Create;
var
  ScreenService: IFMXScreenService;
begin
  inherited Create;
  FRenderLock := TObject.Create;
  FWindows := TList<TAndroidWindowHandle>.Create;
  FVisibleStack := TStack<TAndroidWindowHandle>.Create;
  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, ScreenService) then
    FScale := ScreenService.GetScreenScale
  else
    raise Exception.Create('Correct working of window manager requires IFMXScreenService.');
  TMessageManager.DefaultManager.SubscribeToMessage(TVKStateChangeMessage, VKStateHandler);

  if not TPlatformServices.Current.SupportsPlatformService(IFMXTimerService, FTimerService) then
    raise Exception.Create('Correct working of window manager requires IFMXTimerService.');

  TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, FVirtualKeyboard);
end;

procedure TWindowManager.CreatePasteMenuTimer;
begin
  if FPasteMenuTimer = 0 then
    FPasteMenuTimer := FTimerService.CreateTimer(HidePasteMenuDelay, PasteMenuTimerCall);
end;

function TWindowManager.CreateWindow(const AForm: TCommonCustomForm): TWindowHandle;
begin
  Result := nil;
  if (AForm.Handle <> nil) and Windows.Contains(TAndroidWindowHandle(AForm.Handle)) then
    raise Exception.Create('Window already exists.');

  Result := TAndroidWindowHandle.Create(AForm);
  AddWindow(TAndroidWindowHandle(Result));
  if not IsPopupForm(AForm) then
    TAndroidWindowHandle(Result).Bounds := TRectF.Create(ContentRect);
end;

destructor TWindowManager.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TVKStateChangeMessage, VKStateHandler);
  //fix by 10.2.1
  FTimerService.DestroyTimer(FRenderTimer);
  FVirtualKeyboard := nil;
  FVisibleStack.DisposeOf;
  FWindows.DisposeOf;
  SetFocusedControl(nil);
  FContextMenuPopup := nil;
  FContextMenuLayout := nil;
  FContextButtonsLayout := nil;
  FCopyButton := nil;
  FCopyClickListener := nil;
  FCutButton := nil;
  FCutClickListener := nil;
  FPasteButton := nil;
  FPasteClickListener := nil;
  FMouseDownControl := nil;
  FreeAndNil(FMultiTouchManager);
  inherited;
end;

procedure TWindowManager.DestroyPasteMenuTimer;
begin
  if FPasteMenuTimer <> 0 then
  begin
    FTimerService.DestroyTimer(FPasteMenuTimer);
    FPasteMenuTimer := 0;
  end;
end;

procedure TWindowManager.DestroyWindow(const AForm: TCommonCustomForm);
begin
  if (AForm.Handle <> nil) and Windows.Contains(TAndroidWindowHandle(AForm.Handle)) then
    Windows.Remove(TAndroidWindowHandle(AForm.Handle));
end;

procedure TWindowManager.EndSelection;
begin
  FSelectionInProgress := False;
end;

procedure TWindowManager.BeginSelection;
begin
  FSelectionInProgress := True;
end;

procedure TWindowManager.Activate(const AForm: TCommonCustomForm);
var
  MapManager: IFMXMapService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXMapService, MapManager) then
    MapManager.RealignMapViews;
end;

procedure TWindowManager.BringToFront(const AForm: TCommonCustomForm);
begin
  if AForm.Handle <> nil then
    BringToFront(TAndroidWindowHandle(AForm.Handle));
end;

procedure TWindowManager.AddWindow(const AHandle: TAndroidWindowHandle);
begin
  FWindows.Add(AHandle);
end;

procedure TWindowManager.BringToFront(const AHandle: TAndroidWindowHandle);
begin
  if FWindows.Contains(AHandle) then
  begin
    FWindows.Remove(AHandle);
    FWindows.Add(AHandle);
    if (FVisibleStack.Count = 0) or (FVisibleStack.Peek <> AHandle) then
      FVisibleStack.Push(AHandle);
    SetNeedsRender;
  end;
end;

function TWindowManager.ScreenToClient(const Handle: TAndroidWindowHandle; const Point: TPointF): TPointF;
begin
  if Handle <> nil then
    Result := Point - Handle.Bounds.TopLeft
  else
    Result := Point;
end;

function TWindowManager.ScreenToClient(const AForm: TCommonCustomForm; const Point: TPointF): TPointF;
begin
  Result := ScreenToClient(TAndroidWindowHandle(AForm.Handle), Point);
end;

function TWindowManager.SendCMGestureMessage(AEventInfo: TGestureEventInfo): Boolean;
var
  Window: TAndroidWindowHandle;
  Obj, LFocusedControl: IControl;
  OldGestureControl: TComponent;
  TmpControl: TFmxObject;
  GObj: IGestureControl;
  ClientEventInfo: TGestureEventInfo;
  TextInput: ITextInput;
  TextActions: ITextActions;
const
  LGestureMap: array [igiZoom .. igiDoubleTap] of TInteractiveGesture =
    (TInteractiveGesture.Zoom, TInteractiveGesture.Pan,
    TInteractiveGesture.Rotate, TInteractiveGesture.TwoFingerTap,
    TInteractiveGesture.PressAndtap, TInteractiveGesture.LongTap,
    TInteractiveGesture.DoubleTap);
begin
  Result := False;
  OldGestureControl := nil;
  Window := FindWindowByPoint(AEventInfo.Location.X, AEventInfo.Location.Y);
  if Window <> nil then
  begin
    if TInteractiveGestureFlag.gfBegin in AEventInfo.Flags then
    begin
      // find the control from under the gesture
      Obj := Window.Form.ObjectAtPoint(AEventInfo.Location);
      if FGestureControl <> nil then
        OldGestureControl := FGestureControl;
      if Obj <> nil then
        FGestureControl := Obj.GetObject
      else
        FGestureControl := Window.Form;

      if Supports(FGestureControl, IGestureControl, GObj) then
        FGestureControl := GObj.GetFirstControlWithGesture(LGestureMap[AEventInfo.GestureID])
      else
        FGestureControl := nil;
    end;

    if not FSelectionInProgress then
      if Window.Form.Focused <> nil then
      begin
        LFocusedControl := Window.Form.Focused;
        if LFocusedControl is TStyledPresentation then
          LFocusedControl := TStyledPresentation(LFocusedControl).PresentedControl;
        if Window.Form.Focused <> LFocusedControl then
          SetFocusedControl(LFocusedControl);
      end
      else if FFocusedControl <> nil then
        SetFocusedControl(nil);

    if FGestureControl <> nil then
    begin
      if Supports(FGestureControl, IGestureControl, GObj) then
        try
          ClientEventInfo := AEventInfo;
          ClientEventInfo.Location := Window.Form.ScreenToClient(ClientEventInfo.Location);
          GObj.CMGesture(ClientEventInfo);
        except
          Application.HandleException(FGestureControl);
        end;

      if not FSelectionInProgress then
      begin
        Obj := Window.Form.ObjectAtPoint(AEventInfo.Location);
        if Obj <> nil then
          TmpControl := Obj.GetObject
        else
          TmpControl := Window.Form;

        if TmpControl is TStyledPresentation then
          TmpControl := TStyledPresentation(TmpControl).PresentedControl;

        if (AEventInfo.GestureID = igiLongTap) and Supports(TmpControl, ITextInput, TextInput) and
          Supports(TmpControl, ITextActions, TextActions) then
        begin
          TextActions.SelectWord;
          TTextServiceAndroid(TextInput.GetTextService).InternalUpdateSelection;
          ShowContextMenu;
        end;

        if AEventInfo.GestureID = igiDoubleTap then
        begin
          while (TmpControl <> nil) and
            not (Supports(TmpControl, ITextInput, TextInput) and Supports(TmpControl, ITextActions, TextActions)) do
            TmpControl := TmpControl.Parent;
          if (TextInput <> nil) and (TextActions <> nil) then
          begin
            TTextServiceAndroid(TextInput.GetTextService).InternalUpdateSelection;
            if not TextInput.GetSelection.IsEmpty then
              ShowContextMenu;
          end;
        end;
      end;
      Result := True;
    end
    else
      FGestureControl := OldGestureControl;
  end;
  if TInteractiveGestureFlag.gfEnd in AEventInfo.Flags then
    FGestureControl := nil;
end;

procedure TWindowManager.SendToBack(const AForm: TCommonCustomForm);
begin
  if AForm.Handle <> nil then
    SendToBack(TAndroidWindowHandle(AForm.Handle));
end;

procedure TWindowManager.SendToBack(const AHandle: TAndroidWindowHandle);
begin
  if FWindows.Contains(AHandle) then
  begin
    FWindows.Remove(AHandle);
    FWindows.Insert(0, AHandle);
    SetNeedsRender;
  end;
end;

function TWindowManager.FindForm(const AHandle: TWindowHandle): TCommonCustomForm;
begin
  Result := nil;
  if FWindows.Contains(TAndroidWindowHandle(AHandle)) then
    Result := FWindows[FWindows.IndexOf(TAndroidWindowHandle(AHandle))].Form;
end;

function TWindowManager.FindTopWindow: TAndroidWindowHandle;
var
  I: Integer;
begin
  for I := FWindows.Count - 1 downto 0 do
    if FWindows[I].Form.Visible then
      Exit(FWindows[I]);
  Result := nil;
end;

function TWindowManager.FindTopWindowForTextInput: TAndroidWindowHandle;
var
  I: Integer;
begin
  for I := FWindows.Count - 1 downto 0 do
    if FWindows[I].Form.Visible and not (FWindows[I].Form is TCustomPopupForm) then
      Exit(FWindows[I]);
  Result := nil;
end;

function TWindowManager.FindWindowByPoint(X, Y: Single): TAndroidWindowHandle;
var
  I: Integer;
begin
  for I := FWindows.Count - 1 downto 0 do
    if FWindows[I].Form.Visible and FWindows[I].Bounds.Contains(PointF(X, Y)) then
      Exit(FWindows[I]);
  Result := nil;
end;

procedure TWindowManager.FreeNotification(AObject: TObject);
begin
  FFocusedControl := nil;
end;

function TWindowManager.GetClientSize(const AForm: TCommonCustomForm): TPointF;
begin
  if not IsPopupForm(AForm) then
//    Result := TPointF.Create(ContentRect.Width, ContentRect.Height)
//https://quality.embarcadero.com/browse/RSP-19681
//fix or add by flying wang.
//fix by swish QDAC
//qdac swish 修正，高勇发现这个bug
  begin
    if ContentRect.IsEmpty then
    begin
      with Screen.WorkAreaRect do
        Result:=TPointF.Create(Width, Height);
    end
    else
      Result := TPointF.Create(ContentRect.Width, ContentRect.Height);
  end
  else
    Result := TAndroidWindowHandle(AForm.Handle).Bounds.Size;
end;

class function TWindowManager.GetInstance: TWindowManager;
begin
  if FInstance = nil then
    FInstance := TWindowManager.Create;
  Result := FInstance;
end;

function TWindowManager.GetMultiTouchManager: TMultiTouchManagerAndroid;
var
  Window: TAndroidWindowHandle;
begin
  Window := FindTopWindow;
  if Window <> nil then
    if FMultiTouchManager = nil then
      FMultiTouchManager := TMultiTouchManagerAndroid.Create(Window.Form)
    else
      if FMultiTouchManager.Parent <> Window.Form then
        FMultiTouchManager.Parent := Window.Form;

  Result := FMultiTouchManager;
end;

function TWindowManager.GetWindowRect(const AForm: TCommonCustomForm): TRectF;
begin
  if IsPopupForm(AForm) then
    Result := TAndroidWindowHandle(AForm.Handle).Bounds
  else
    Result := ContentRect;
end;

function TWindowManager.GetWindowScale(const AForm: TCommonCustomForm): Single;
begin
  Result := Scale;
end;

function TWindowManager.TextGetService: TTextServiceAndroid;
var
  TextInput: ITextInput;
begin
  Result := nil;
  if Supports(FFocusedControl, ITextInput, TextInput) then
    Result := TTextServiceAndroid(TextInput.GetTextService);
end;

function TWindowManager.TextGetActions: ITextActions;
begin
  Supports(FFocusedControl, ITextActions, Result);
end;

function TWindowManager.TextReadOnly: Boolean;
var
  ReadOnly: IReadOnly;
begin
  Result := True;
  if Supports(FFocusedControl, IReadOnly, ReadOnly) then
    Result := ReadOnly.ReadOnly;
end;

procedure TWindowManager.TextResetSelection;
var
  TextActions: ITextActions;
begin
  if Supports(FFocusedControl, ITextActions, TextActions) then
    TextActions.ResetSelection;
end;

procedure TWindowManager.KeyDown(var Key: Word; var KeyChar: System.WideChar; Shift: TShiftState);
var
  Window: TAndroidWindowHandle;
begin
  HideContextMenu;
  Window := FindTopWindowForTextInput;
  if Window <> nil then
    try
      Window.Form.KeyDown(Key, KeyChar, Shift);
    except
      Application.HandleException(Window.Form);
    end;
end;

procedure TWindowManager.KeyUp(var Key: Word; var KeyChar: System.WideChar; Shift: TShiftState; KeyDownHandled: Boolean);
var
  Window: TAndroidWindowHandle;

  function HideVKB: Boolean;
  var
    //Fix By 爱吃猪头肉 & Flying Wang
    VKObj: IVirtualKeyboardControl;
  begin
    if FVirtualKeyboard <> nil then
    begin
      Result := FVirtualKeyboard.GetVirtualKeyboardState * [TVirtualKeyboardState.Visible] <> [];
      //Fix By 爱吃猪头肉 & Flying Wang
      //请使用 fixed FMX.VirtualKeyboard.Android
      if (not Result) and vkHardwareBackMustKillFocused and (Screen.ActiveForm.Focused <> nil) then
      begin
        VKObj := nil;
        Screen.ActiveForm.Focused.QueryInterface(IVirtualKeyboardControl, VKObj);
        Result := (VKObj <> nil);
      end;
      if Result then
      begin
        Key := 0;
        KeyChar := #0;
        Screen.ActiveForm.Focused := nil;
        FVirtualKeyboard.HideVirtualKeyboard
      end;
    end
    else
      Result := True;
  end;

begin
  Window := FindTopWindowForTextInput;
  if Window <> nil then
    try
      Window.Form.KeyUp(Key, KeyChar, Shift);
    except
      Application.HandleException(Window.Form);
    end;
  // some actions by default
  if KeyDownHandled and (Key = vkHardwareBack) then // If you press of key was processed
    HideVKB
  else // If you press of key wasn't processed
    case Key of
      vkHardwareBack:
        begin
          if not HideVKB and (Window <> nil) then
          begin
            try
              Key := 0;
              KeyChar := #0;
              Window.Form.Close;
            except
              Application.HandleException(Window.Form);
            end;

            if Application.MainForm <> Window.Form then
            begin
              if (FVisibleStack.Count > 0) and (FVisibleStack.Peek = Window) then
                  FVisibleStack.Pop;
              if (FVisibleStack.Count > 0) and (FVisibleStack.Peek <> nil) then
                BringToFront(FVisibleStack.Peek);
            end
            else
              Application.Terminate;  //we have close the main form
          end;
        end
    end
end;

procedure TWindowManager.PrepareClosePopups(const SaveForm: TAndroidWindowHandle);
begin
  if Screen <> nil then
    if SaveForm <> nil then
      Screen.PrepareClosePopups(SaveForm.Form)
    else
      Screen.PrepareClosePopups(nil);
end;

function TWindowManager.ClientToScreen(const AForm: TCommonCustomForm; const Point: TPointF): TPointF;
begin
  if AForm <> nil then
    Result := Point + TAndroidWindowHandle(AForm.Handle).Bounds.TopLeft
  else
    Result := Point;
end;

procedure TWindowManager.ClosePopups;
begin
  if Screen <> nil then
    Screen.ClosePopupForms;
end;

procedure TWindowManager.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Window: TAndroidWindowHandle;
  ClientPoint: TPointF;
  Obj: IControl;
  GObj: IGestureControl;
begin
  Window := FindWindowByPoint(X, Y);
  if Window <> nil then
  begin
    PrepareClosePopups(Window);
    ClientPoint := ScreenToClient(Window, TPointF.Create(X, Y));
    try
      Window.Form.MouseMove([ssTouch], ClientPoint.X, ClientPoint.Y);
      Window.Form.MouseMove([], ClientPoint.X, ClientPoint.Y); // Required for correct IsMouseOver handling
      Window.Form.MouseDown(TMouseButton.mbLeft, Shift, ClientPoint.X, ClientPoint.Y);
    except
      Application.HandleException(Window.Form);
    end;
    // find the control from under the gesture
    Obj := Window.Form.ObjectAtPoint(Window.Form.ClientToScreen(ClientPoint));
    if Obj <> nil then
      FGestureControl := Obj.GetObject
    else
      FGestureControl := Window.Form;

    if FGestureControl is TControl then
      FMouseDownControl := TControl(FGestureControl);
    if FMouseDownControl is TStyledPresentation then
      FMouseDownControl := TStyledPresentation(FMouseDownControl).PresentedControl;

    HideContextMenu;

    if Supports(FGestureControl, IGestureControl, GObj) then
      FGestureControl := GObj.GetFirstControlWithGestureEngine;

    if Supports(FGestureControl, IGestureControl, GObj) then
    begin
      TPlatformGestureEngine(GObj.TouchManager.GestureEngine).InitialPoint := ClientPoint;

      // Retain the points/touches.
      TPlatformGestureEngine(GObj.TouchManager.GestureEngine).ClearPoints;
      TPlatformGestureEngine(GObj.TouchManager.GestureEngine).AddPoint(ClientPoint.X, ClientPoint.Y);
    end;
  end;
end;

procedure TWindowManager.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Window: TAndroidWindowHandle;
  ClientPoint: TPointF;
  GObj: IGestureControl;
begin
  if FCapturedWindow <> nil then
    Window := FCapturedWindow
  else
    Window := FindWindowByPoint(X, Y);
  if Window <> nil then
  begin
    ClientPoint := ScreenToClient(Window, TPointF.Create(X, Y));
    try
      Window.Form.MouseMove(Shift, ClientPoint.X, ClientPoint.Y);
    except
      Application.HandleException(Window.Form);
    end;
    if Supports(FGestureControl, IGestureControl, GObj) and (GObj.TouchManager.GestureEngine <> nil) then
      TPlatformGestureEngine(GObj.TouchManager.GestureEngine).AddPoint(ClientPoint.X, ClientPoint.Y);
  end;
end;

procedure TWindowManager.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single; DoCLick: Boolean);
const
  LGestureTypes: TGestureTypes = [TGestureType.Standard, TGestureType.Recorded, TGestureType.Registered];
var
  Window: TAndroidWindowHandle;
  ClientPoint: TPointF;
  EventInfo: TGestureEventInfo;
  GObj: IGestureControl;
begin
  //add by Zeus64
  //https://quality.embarcadero.com/browse/RSP-16369
  //when we swipe fastly the finger from one side to another side to finally get out of the screen
  //then the coordinnate are sometime "out of the screen" (ex: x: -5)
  X := min(ContentRect.right - 1, max(ContentRect.Left, X));
  y := min(ContentRect.bottom - 1, max(ContentRect.top, y));

  if FCapturedWindow <> nil then
    Window := FCapturedWindow
  else
    Window := FindWindowByPoint(X, Y);
  if Window <> nil then
  begin
    ClientPoint := ScreenToClient(Window, TPointF.Create(X, Y));
    try
      Window.Form.MouseUp(TMouseButton.mbLeft, Shift, ClientPoint.X, ClientPoint.Y, DoClick);
      if Window.Form <> nil then
        Window.Form.MouseLeave; // Require for correct IsMouseOver handle
      ClosePopups;
    except
      Application.HandleException(Window.Form);
    end;
    if Supports(FGestureControl, IGestureControl, GObj) then
      if GObj.TouchManager.GestureEngine <> nil then
      begin
        if TPlatformGestureEngine(GObj.TouchManager.GestureEngine).PointCount > 1 then
        begin
          FillChar(EventInfo, Sizeof(EventInfo), 0);
          if TPlatformGestureEngine.IsGesture
            (TPlatformGestureEngine(GObj.TouchManager.GestureEngine).Points,
            TPlatformGestureEngine(GObj.TouchManager.GestureEngine).GestureList, LGestureTypes, EventInfo) then
            TPlatformGestureEngine(GObj.TouchManager.GestureEngine).BroadcastGesture(FGestureControl, EventInfo);
        end;
      end;
  end;
end;

procedure TWindowManager.MultiTouch(const Touches: TTouches; const Action: TTouchAction; const AEnabledGestures: TInteractiveGestures);
var
  Window: TAndroidWindowHandle;
  Control: IControl;
  I: Integer;
begin
  if FCapturedWindow <> nil then
    Window := FCapturedWindow
  else
    Window := FindWindowByPoint(Touches[0].Location.X, Touches[0].Location.Y);
  if Window <> nil then
  begin
    if Length(Touches) = 1 then
      Control := Window.Form.ObjectAtPoint(Touches[0].Location)
    else if Length(Touches) = 2 then
      Control := Window.Form.ObjectAtPoint(Touches[0].Location.MidPoint(Touches[1].Location))
    else
      Control := nil;

    for I := 0 to Length(Touches) - 1 do
      Touches[I].Location := Window.Form.ScreenToClient(Touches[I].Location);

    MultiTouchManager.SetEnabledGestures(AEnabledGestures);
    MultiTouchManager.HandleTouches(Touches, Action, Control);
  end;
end;

procedure TWindowManager.PasteMenuTimerCall;
begin
  DestroyPasteMenuTimer;
  //
  HideContextMenu;
end;

function TWindowManager.PixelToPoint(const P: TPointF): TPointF;
begin
  Result := TPointF.Create(P.X / FScale, P.Y / FScale);
end;

function TWindowManager.PointToPixel(const P: TPointF): TPointF;
begin
  Result := TPointF.Create(P.X * FScale, P.Y * FScale);
end;

procedure TWindowManager.ReleaseCapture(const AForm: TCommonCustomForm);
begin
   FCapturedWindow := nil;
end;

procedure TWindowManager.ReleaseWindow(const AForm: TCommonCustomForm);
begin
  if (AForm.Handle <> nil) and Windows.Contains(TAndroidWindowHandle(AForm.Handle)) then
    RemoveWindow(TAndroidWindowHandle(AForm.Handle));
end;

procedure TWindowManager.RemoveWindow(const AHandle: TAndroidWindowHandle);
begin
  if FVisibleStack.Peek = AHandle then
    FVisibleStack.Pop;
  FWindows.Remove(AHandle);
  FMouseDownControl := nil;
  SetFocusedControl(nil);
  FGestureControl := nil;
  SetNeedsRender;
end;

function TWindowManager.AlignToPixel(const Value: Single): Single;
begin
  Result := Round(Value * Scale) / Scale;
end;

procedure TWindowManager.InitWindow;
begin
  TContext3D.ResetStates;
  FContext := TCustomAndroidContext.CreateContextFromActivity(Round(FContentRect.Width * FScale),
     Round(FContentRect.Height * FScale), TMultisample.None, False);
end;

procedure TWindowManager.TermWindow;
begin
  FContext.DisposeOf;
  FContext := nil;
end;

procedure TWindowManager.GainedFocus;
begin
  TContext3D.ResetStates;
end;

procedure TWindowManager.PostRenderRunnable;
begin
  if (not Pause) and (FRenderRunnable = nil) then
  begin
    TMonitor.Enter(FRenderLock);
    try
      FRenderRunnable := TRenderRunnable.Create(Self)
    finally
      TMonitor.Exit(FRenderLock);
    end;
  end;
end;

procedure TWindowManager.ReleaseRenderRunnable;
begin
  TMonitor.Enter(FRenderLock);
  try
    FRenderRunnable := nil;
  finally
    TMonitor.Exit(FRenderLock);
  end;
end;

procedure TWindowManager.Render;

  function HaveAnyCompositionedWindows: Boolean;
  var
    I: Integer;
  begin
    for I := 0 to FWindows.Count - 1 do
      if FWindows[I].Form.Visible and FWindows[I].RequiresComposition then
        Exit(True);

    Result := False;
  end;

  procedure RenderNormalWindows;
  var
    I: Integer;
    PaintControl: IPaintControl;
  begin
    for I := FWindows.Count - 1 downto 0 do
      if FWindows[I].Form.Visible and not FWindows[I].RequiresComposition and Supports(FWindows[I].Form,
        IPaintControl, PaintControl) then
      begin
        PaintControl.PaintRects([TRectF.Create(0, 0, FContentRect.Width, FContentRect.Height)]);
        Break;
      end;
  end;

  procedure RenderBuffers;
  var
    I: Integer;
    CurrentForm: TAndroidWindowHandle;
    FormBounds: TRectF;
  begin
    for I := FWindows.Count - 1 downto 0 do
    begin
      CurrentForm := FWindows[I];

      if CurrentForm.RequiresComposition and (CurrentForm.Texture <> nil) and CurrentForm.Form.Visible then
      begin
        FormBounds := CurrentForm.Bounds;
        if CurrentForm.NeedsUpdate then
        begin
          IPaintControl(CurrentForm.Form).PaintRects([RectF(0, 0, FormBounds.Width, FormBounds.Height)]);
          CurrentForm.NeedsUpdate := False;
        end;
      end;
    end;
  end;

  procedure RenderCompositionedWindows;
  var
    I: Integer;
    Mat: TCanvasTextureMaterial;
    Ver: TVertexBuffer;
    Ind: TIndexBuffer;
    CurrentForm: TAndroidWindowHandle;
    FormBounds: TRectF;
  begin
    Ver := TVertexBuffer.Create([TVertexFormat.Vertex, TVertexFormat.TexCoord0, TVertexFormat.Color0], 4);
    Ver.Color0[0] := $FFFFFFFF;
    Ver.Color0[1] := $FFFFFFFF;
    Ver.Color0[2] := $FFFFFFFF;
    Ver.Color0[3] := $FFFFFFFF;
    Ver.TexCoord0[0] := PointF(0.0, 1.0);
    Ver.TexCoord0[1] := PointF(1.0, 1.0);
    Ver.TexCoord0[2] := PointF(1.0, 0.0);
    Ver.TexCoord0[3] := PointF(0.0, 0.0);

    Ind := TIndexBuffer.Create(6);
    Ind[0] := 0;
    Ind[1] := 1;
    Ind[2] := 3;
    Ind[3] := 3;
    Ind[4] := 1;
    Ind[5] := 2;

    Mat := TCanvasTextureMaterial.Create;

    for I := FWindows.Count - 1 downto 0 do
    begin
      CurrentForm := FWindows[I];

      if CurrentForm.RequiresComposition and (CurrentForm.Texture <> nil) and CurrentForm.Form.Visible then
      begin
        FormBounds := CurrentForm.Bounds;
        FormBounds.Offset(-FContentRect.Left, -FContentRect.Top);

        FormBounds.Left := Round(FormBounds.Left * Scale);
        FormBounds.Top := Round(FormBounds.Top * Scale);
        FormBounds.Right := FormBounds.Left + CurrentForm.Texture.Width;
        FormBounds.Bottom := FormBounds.Top + CurrentForm.Texture.Height;

        Ver.Vertices[0] := TPoint3D.Create(FormBounds.Left, FormBounds.Top, 0);
        Ver.Vertices[1] := TPoint3D.Create(FormBounds.Right, FormBounds.Top, 0);
        Ver.Vertices[2] := TPoint3D.Create(FormBounds.Right, FormBounds.Bottom, 0);
        Ver.Vertices[3] := TPoint3D.Create(FormBounds.Left, FormBounds.Bottom, 0);

        Mat.Texture := CurrentForm.Texture;

        FContext.SetMatrix(TMatrix3D.Identity);
        FContext.SetContextState(TContextState.cs2DScene);
        FContext.SetContextState(TContextState.csZWriteOff);
        FContext.SetContextState(TContextState.csZTestOff);
        FContext.SetContextState(TContextState.csAllFace);
        FContext.SetContextState(TContextState.csScissorOff);
        if CurrentForm.Form.Transparency then
          FContext.SetContextState(TContextState.csAlphaBlendOn)
        else
          FContext.SetContextState(TContextState.csAlphaBlendOff);

        FContext.DrawTriangles(Ver, Ind, Mat, 1);
      end;

      Mat.Free;
      Ind.Free;
      Ver.Free;
    end;
  end;

begin
  if (FContext <> nil) and not FPause then
  begin
    if HaveAnyCompositionedWindows then
      RenderBuffers;

    if FContext.BeginScene then
    try
      // Render normal opaque windows that are occupying entire client space.
      RenderNormalWindows;

      // If there are any visible popups or transparent windows, render them using buffered texture.
      if HaveAnyCompositionedWindows then
        RenderCompositionedWindows;
    finally
      FContext.EndScene;
    end;
  end;
  FNeedsRender := False;
end;

function TWindowManager.RenderIfNeeds: Boolean;
begin
  Result := FNeedsRender;
  if FNeedsRender then
    Render;
end;

procedure TWindowManager.RenderImmediately;
begin
  SetNeedsRender;
  RenderIfNeeds;
end;

procedure TWindowManager.SetCapture(const AForm: TCommonCustomForm);
begin
  FCapturedWindow := TAndroidWindowHandle(AForm.Handle);
end;

procedure TWindowManager.SetClientSize(const AForm: TCommonCustomForm; const ASize: TPointF);
var
  Bounds: TRectF;
begin
  if IsPopupForm(AForm) then
  begin
    Bounds := TAndroidWindowHandle(AForm.Handle).Bounds;
    TAndroidWindowHandle(AForm.Handle).Bounds := TRectF.Create(Bounds.TopLeft, ASize.X, ASize.Y);
  end;
end;

procedure TWindowManager.SetContentRect(const Value: TRect);
var
  DecorView: JView;
  NativeWin: JWindow;
  ContentRect: JRect;
  //Fix By Flying Wang.
  ContentRectVisible: JRect;
  FLAG_FULLSCREEN,
  FLAG_TRANSLUCENT_STATUS,
  Attributes_flags: Integer;
  IsFullScreen: Boolean;
begin
//  if FContentRect <> Value then
  //Fix By Flying Wang.
  if (FContentRect <> Value) or TempForceUpdateScreenSize then
  begin
    FContentRect := TRect.Create(Round(Value.left / FScale), Round(Value.top / FScale), Round(Value.right / FScale), Round(Value.bottom / FScale));;
    NativeWin := TAndroidHelper.Activity.getWindow;
    if NativeWin <> nil then
    begin
      ContentRect := TJRect.Create;
      DecorView := NativeWin.getDecorView;
      DecorView.getDrawingRect(ContentRect);
      FContentRect.Bottom := Round(ContentRect.bottom / FScale);
      FContentRect.Right := Round(ContentRect.right / FScale);
    end;
    FStatusBarHeight := Value.Top;


    //Fix by Flying Wang & 爱吃猪头肉。
    if not TempForceUpdateScreenSize then
    begin
      CallInUIThread(procedure () begin
        IsFullScreen := PlatformAndroid.ScreenManager.GetFullScreen(nil);
      end);
    end;
    if TempForceUpdateScreenSize then
    begin
      //感谢 [龟山]阿卍(1467948783) 帮忙调试。
      //http://www.2cto.com/kf/201307/227536.html
      ContentRectVisible := TJRect.Create;
      DecorView.getWindowVisibleDisplayFrame(ContentRectVisible);
      IsFullScreen := False;
      //if (FContentRect.Top < 1) or (ContentRectVisible.Top < FStatusBarHeight) then
      begin
        Attributes_flags := 0;
        FLAG_FULLSCREEN := -1;
        FLAG_TRANSLUCENT_STATUS := -1;
        CallInUIThread(procedure () begin
//          IsFullScreen := PlatformAndroid.ScreenManager.GetFullScreen(nil);
          Attributes_flags := TAndroidHelper.Activity.getWindow.getAttributes.flags;
          FLAG_FULLSCREEN := TJWindowManager_LayoutParams.JavaClass.FLAG_FULLSCREEN;
          if TOSVersion.Check(4,4) then
            FLAG_TRANSLUCENT_STATUS := TJWindowManager_LayoutParams.JavaClass.FLAG_TRANSLUCENT_STATUS;
        end);
        if (not IsFullScreen) and
          (Attributes_flags and FLAG_FULLSCREEN <> FLAG_FULLSCREEN) and
          (Attributes_flags and FLAG_TRANSLUCENT_STATUS <> FLAG_TRANSLUCENT_STATUS) then
        begin
          ContentRect.top := ContentRectVisible.Top;
          if not (TOSVersion.Architecture in [arARM32, arARM64]) then
          begin
            CallInUIThread(procedure () begin
              if GetNavigationBarPixelHeight <> 0 then
              begin
                // - Trunc(FScale) 是为了消除，可能存在的小白线。
                ContentRect.top := GetStatusBarPixelHeight - Trunc(FScale);
              end;
            end);
          end;
        end;
        if (Attributes_flags and
          FLAG_TRANSLUCENT_STATUS = FLAG_TRANSLUCENT_STATUS) or IsFullScreen then
        begin
          ContentRect.top := 0;
        end;
      end;
      //fix for [西安]高勇(120180714);
      //for FullScreen Status Show User Color
      if ForceNoStatusBar then
      begin
        ContentRect.top := 0;
      end;
      FContentRect.Top := Trunc(ContentRect.top / FScale);
      FContentRect.Left := Trunc(ContentRect.left / FScale);
      FContentRect.Bottom := Round(ContentRect.bottom / FScale);
      FContentRect.Right := Round(ContentRect.right / FScale);
      FStatusBarHeight := Trunc(ContentRect.top  / FScale);

      TempForceUpdateScreenSize := False;
    end;

    //Fix or Add By 爱吃猪头肉
    CurrStatusBarPixelHeight := FStatusBarHeight * FScale;
    CallInUIThread(procedure () begin
      CurrStatusBarPixelHeight := GetStatusBarPixelHeight;
    end);
    if IsFullScreen or ForceNoStatusBar then
      CurrStatusBarPixelHeight := 0;
    CurrStatusBarFmxHeight := CurrStatusBarPixelHeight / FScale;

//    //fix for Redmi Note 5 失败
//    //test by [青岛]东南(40847505)
//增加 高度 或减小高度，都会从底部开始显示，
//增加，会导致头部顶上去。
//减小，会导致头部下沉。
//      FContentRect.Height := xxx;
    //fix end.

    UpdateFormSizes;
    PlatformAndroid.ScreenManager.UpdateDisplayInformation;
    if FContext <> nil then
      FContext.SetSize(Round(FContentRect.Width * FScale), Round(FContentRect.Height * FScale));
    SetNeedsRender;
    Render;
  end;
end;

procedure TWindowManager.SetFocusedControl(const Control: IControl);
begin
  if FFocusedControl <> Control then
  begin
    if FFocusedControl <> nil then
      FFocusedControl.RemoveFreeNotify(Self);
    FFocusedControl := Control;
    if FFocusedControl <> nil then
      FFocusedControl.AddFreeNotify(Self);
  end;
end;

procedure TWindowManager.SetNeedsRender;
begin
////fix or remove by flying wang.
//  if not FNeedsRender then
//  begin
//    FNeedsRender := True;
//    PostRenderRunnable;
//  end;
//fix by 10.2.1
  if not FNeedsRender then
  begin
    FNeedsRender := True;
    CreateRenderTimer;
  end;
end;

procedure TWindowManager.SetPause(const Value: Boolean);
begin
  FPause := Value;
end;

procedure TWindowManager.SetWindowCaption(const AForm: TCommonCustomForm; const ACaption: string);
begin
  // NOP on Android
end;

procedure TWindowManager.SetWindowRect(const AForm: TCommonCustomForm; ARect: TRectF);
begin
  if IsPopupForm(AForm) then
    TAndroidWindowHandle(AForm.Handle).Bounds := ARect;
end;

procedure TWindowManager.SetWindowState(const AForm: TCommonCustomForm; const AState: TWindowState);
begin
  if AForm.Visible and (AState = TWindowState.wsMinimized) then
    AForm.Visible := False;
  if AForm.Visible then
    if IsPopupForm(AForm) then
      AForm.WindowState := TWindowState.wsNormal
    else
      AForm.WindowState := TWindowState.wsMaximized
  else
    AForm.WindowState := TWindowState.wsMinimized;
end;

procedure TWindowManager.ShowContextMenu(const ItemsToShow: TContextMenuItems);
var
  LA: TTextLayout;
  P: TPoint;
  HasSelection, HasClipboard: Boolean;
  ApproxWidth: Integer;
  ApproxHeight: Integer;
  ClipboardValue: TValue;
  ResID: Integer;
  TextInput: ITextInput;
  VirtualKeyboard: IVirtualKeyboardControl;
  ClipboardSvc: IFMXClipboardService;
begin
  DestroyPasteMenuTimer;
  ApproxWidth := FContextMenuPopupSize.cx;
  ApproxHeight := FContextMenuPopupSize.cy;
  if not FContextMenuVisible and Supports(FFocusedControl, ITextInput, TextInput) and not FSelectionInProgress then
  begin
    FContextMenuVisible := True;
    HasSelection := not TextInput.GetSelection.IsEmpty;
    TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, ClipboardSvc);
    ClipboardValue := ClipboardSvc.GetClipboard;
    HasClipboard := not ClipboardValue.IsEmpty and not ClipboardValue.ToString.IsEmpty;

//fix by or add by flyign wang.
//fix by Alysson Cunha
//https://quality.embarcadero.com/browse/RSP-16935
    FCopyButton := nil;
    FPasteButton := nil;
    FCutButton := nil;

    if FContextMenuPopup = nil then
    begin
      FContextMenuLayout := TJLinearLayout.JavaClass.init(TAndroidHelper.Activity);
      FContextButtonsLayout := TJLinearLayout.JavaClass.init(TAndroidHelper.Activity);

      LA := TTextLayoutManager.DefaultTextLayout.Create;
      LA.Font.Style := LA.Font.Style + [TFontStyle.fsBold];

      P := Point(0, 0);
      Supports(FFocusedControl, IVirtualKeyboardControl, VirtualKeyboard);

      if HasSelection then
      begin
        //Copy button
        if (TContextMenuItem.Copy in ItemsToShow) and ((VirtualKeyboard = nil) or not VirtualKeyboard.IsPassword) then
        begin
          ResID := TAndroidHelper.GetResourceID('android:string/copy');
          if ResID <> 0 then
            LA.Text := TAndroidHelper.GetResourceString(ResID)
          else
            LA.Text := SEditCopy.ToUpper;
          FCopyButton := TJButton.JavaClass.init(TAndroidHelper.Activity);
          if ResID <> 0 then
            FCopyButton.setText(ResID)
          else
            FCopyButton.setText(StrToJCharSequence(LA.Text));
          FCopyButton.setTypeface(TJTypeface.JavaClass.DEFAULT_BOLD);
          FCopyClickListener := TCopyButtonClickListener.Create;
          FCopyButton.setOnClickListener(FCopyClickListener);
          LA.Font.Size := FCopyButton.getTextSize;
          P.X := P.X + Ceil((LA.TextWidth + 2) * FScale);
          P.Y := Max(P.Y, Ceil((LA.TextHeight + 2) * FScale));
          ApproxHeight := P.Y + FCopyButton.getPaddingTop + FCopyButton.getPaddingBottom;
        end;
        //Cut button
        if (TContextMenuItem.Cut in ItemsToShow) and not TextReadOnly and ((VirtualKeyboard = nil) or not VirtualKeyboard.IsPassword) then
        begin
          ResID := TAndroidHelper.GetResourceID('android:string/cut');
          if ResID <> 0 then
            LA.Text := TAndroidHelper.GetResourceString(ResID)
          else
            LA.Text := SEditCut.ToUpper;
          FCutButton := TJButton.JavaClass.init(TAndroidHelper.Activity);
          if ResID <> 0 then
            FCutButton.setText(ResID)
          else
            FCutButton.setText(StrToJCharSequence(LA.Text));
          FCutButton.setTypeface(TJTypeface.JavaClass.DEFAULT_BOLD);
          FCutClickListener := TCutButtonClickListener.Create;
          FCutButton.setOnClickListener(FCutClickListener);
          LA.Font.Size := FCopyButton.getTextSize;
          P.X := P.X + Ceil((LA.TextWidth + 2) * FScale);
          P.Y := Max(P.Y, Ceil((LA.TextHeight + 2) * FScale));
        end;
      end;

      if HasClipboard and (TContextMenuItem.Paste in ItemsToShow) and not TextReadOnly then
      begin
        //Paste button
        ResID := TAndroidHelper.GetResourceID('android:string/paste');
        if ResID <> 0 then
          LA.Text := TAndroidHelper.GetResourceString(ResID)
        else
          LA.Text := SEditPaste.ToUpper;
        FPasteButton := TJButton.JavaClass.init(TAndroidHelper.Activity);
        if ResID <> 0 then
          FPasteButton.setText(ResID)
        else
          FPasteButton.setText(StrToJCharSequence(LA.Text));
        FPasteButton.setTypeface(TJTypeface.JavaClass.DEFAULT_BOLD);
        FPasteClickListener := TPasteButtonClickListener.Create;
        FPasteButton.setOnClickListener(FPasteClickListener);
        LA.Font.Size := FPasteButton.getTextSize;
        P.X := P.X + Ceil((LA.TextWidth + 2) * FScale);
        P.Y := Max(P.Y, Ceil((LA.TextHeight + 2) * FScale));
        if ApproxHeight = 0 then
          ApproxHeight := P.Y + FPasteButton.getPaddingTop + FPasteButton.getPaddingBottom;
      end;

      ApproxWidth := P.X;

      FContextMenuPopup := TJPopupWindow.JavaClass.init(TAndroidHelper.Activity);
      FContextMenuPopup.setBackgroundDrawable(TJColorDrawable.JavaClass.init(0));

      FContextMenuPopup.setContentView(FContextButtonsLayout);
      FContextMenuPopup.setWidth(TJViewGroup_LayoutParams.JavaClass.WRAP_CONTENT);
      FContextMenuPopup.setHeight(TJViewGroup_LayoutParams.JavaClass.WRAP_CONTENT);
    end;

    FContextMenuPopupSize.cx := ApproxWidth;
    if FContextMenuPopupSize.cy <= 0 then
    begin
      FContextMenuPopupSize.cy := ApproxHeight;
    end;

    if FCopyButton <> nil then
      FContextButtonsLayout.addView(FCopyButton);
    if FCutButton <> nil then
      FContextButtonsLayout.addView(FCutButton);
    if FPasteButton <> nil then
      FContextButtonsLayout.addView(FPasteButton);
    if (FVirtualKeyboard <> nil) and (TVirtualKeyboardState.Visible in FVirtualKeyboard.VirtualKeyboardState) then
      DoShowContextMenu;
  end;
end;

procedure TWindowManager.ShowWindow(const AForm: TCommonCustomForm);
var
  NativeWin: JWindow;
begin
  if AForm.Handle <> nil then
  begin
    if not IsPopupForm(AForm) then
    begin
      NativeWin := TAndroidHelper.Activity.getWindow;
      if AForm.BorderStyle = TFmxFormBorderStyle.None then
        MainActivity.setStatusBarVisibility(False)
      else
        MainActivity.setStatusBarVisibility(True);
      try
        AForm.SetBounds(ContentRect.Left, ContentRect.Top, ContentRect.Width, ContentRect.Height);
      except
        Application.HandleException(AForm);
      end;
    end
    else
      SetNeedsRender;
    BringToFront(TAndroidWindowHandle(AForm.Handle));
    if IsPopupForm(AForm) then
      AForm.WindowState := TWindowState.wsNormal
    else
      AForm.WindowState := TWindowState.wsMaximized;
  end;
end;

function TWindowManager.ShowWindowModal(const AForm: TCommonCustomForm): TModalResult;
begin
  raise ENotImplemented.CreateFmt(SNotImplementedOnPlatform, ['ShowModal']);
  Result := mrCancel;
end;

function TWindowManager.CanShowModal: Boolean;
begin
  Result := False;
end;

procedure TWindowManager.DoShowContextMenu;
const
  LocTopOffset = 10.0;
  LocBottomOffset = 3 * LocTopOffset;
var
  SelRect: TRectF;
  PopupLoc: TPoint;
  TempPointF: TPointF;
  TextInput: ITextInput;
  LocY: Single;
begin
  if Supports(FFocusedControl, ITextInput, TextInput) and (FContextMenuLayout <> nil) and (FContextMenuPopup <> nil) and
    (FContextButtonsLayout.getChildCount > 0) then
  begin
    SelRect := TextInput.GetSelectionRect;
    TempPointF := FFocusedControl.LocalToScreen(TPointF.Create(SelRect.Left, SelRect.Top)) * FScale;
    TempPointF.X := TempPointF.X + SelRect.Width / 2 - FContextMenuPopupSize.cx / 2;
    LocY := TempPointF.Y - LocTopOffset * FScale - FContextMenuPopupSize.cy;
    if LocY < 0 then
      LocY := TempPointF.Y + (SelRect.Height + LocBottomOffset) * FScale;
    TempPointF.Y := LocY;
    PopupLoc := TempPointF.Round;
    FContextMenuPopup.showAtLocation(FContextMenuLayout, 0, PopupLoc.X, PopupLoc.Y);
  end
  else
    HideContextMenu;
end;

procedure TWindowManager.VKStateHandler(const Sender: TObject; const M: TMessage);
begin
  if TVKStateChangeMessage(M).KeyboardVisible and Supports(FFocusedControl, ITextInput) and (FContextMenuLayout <> nil) and
    (FContextMenuPopup <> nil) and (FContextButtonsLayout.getChildCount > 0) then
    DoShowContextMenu;
end;

procedure TWindowManager.SingleTap;
begin
  if FMouseDownControl <> nil then
    try
      if not FSelectionInProgress then
      begin
        if Supports(FMouseDownControl, ITextInput) and Supports(FMouseDownControl, ITextActions) then
        begin
          if not FIsFirstSingleTap then
          begin
            //Fix or add by flying wang.
            if NoPasteWhenSingleTap then exit;
            ShowContextMenu([TContextMenuItem.Paste]);
            CreatePasteMenuTimer;
          end;
          FIsFirstSingleTap := False;
        end
        else
          HideContextMenu;
      end;
    except
      Application.HandleException(Self);
      FMouseDownControl := nil;
    end;
end;

procedure TWindowManager.HideContextMenu;
begin
  DestroyPasteMenuTimer;
  if FContextMenuVisible and (FContextMenuPopup <> nil) and (FContextButtonsLayout <> nil) then
  begin
    FContextMenuPopupSize.cx := FContextButtonsLayout.getWidth;
    FContextMenuPopupSize.cy := FContextButtonsLayout.getHeight;
    FContextMenuPopup.dismiss;
    FContextMenuPopup := nil;
    FCopyButton := nil;
    FCopyClickListener := nil;
    FPasteButton := nil;
    FPasteClickListener := nil;
    FCutButton := nil;
    FCutClickListener := nil;
    FContextMenuLayout := nil;
    FContextButtonsLayout := nil;
  end;
  FContextMenuVisible := False;
end;

procedure TWindowManager.HideWindow(const AForm: TCommonCustomForm);
begin
  if FVisibleStack.Peek = AForm.Handle then
    FVisibleStack.Pop;
  if AForm.Handle <> nil then
    SetNeedsRender;
  AForm.WindowState := TWindowState.wsMinimized;
end;

procedure TWindowManager.InvalidateImmediately(const AForm: TCommonCustomForm);
begin
  TAndroidWindowHandle(AForm.Handle).NeedsUpdate := True;
  SetNeedsRender;
end;

procedure TWindowManager.InvalidateWindowRect(const AForm: TCommonCustomForm; R: TRectF);
begin
  TAndroidWindowHandle(AForm.Handle).NeedsUpdate := True;
  SetNeedsRender;
end;

function TWindowManager.IsPopupForm(const AForm: TCommonCustomForm): Boolean;
begin
  Result := (AForm <> nil) and ((AForm.FormStyle = TFormStyle.Popup) or (AForm.Owner is TPopup));
end;

procedure TWindowManager.UpdateFormSizes;
var
  I: Integer;
begin
  for I := FWindows.Count - 1 downto 0 do
    if not FWindows[I].IsPopup then
      try
        FWindows[I].SetBounds(FContentRect);
      except
        Application.HandleException(FWindows[I].Form);
      end;
end;

{ TPlatformAndroid }

constructor TPlatformAndroid.Create;
begin
  inherited;
  BindAppGlueEvents;
  { Creates core services }
  FLoggerService := TAndroidLoggerService.Create;
  FTimerService := TAndroidTimerService.Create;
  FSaveStateService := TAndroidSaveStateService.Create;
  FScreenServices := TAndroidScreenServices.Create;
  FMetricsServices := TAndroidMetricsServices.Create;
  FDeviceServices := TAndroidDeviceServices.Create;
  if DeviceManager.GetDeviceClass <> TDeviceInfo.TDeviceClass.Watch then
    FVirtualKeyboardService := TVirtualKeyboardAndroid.Create;
  FGraphicServices := TAndroidGraphicsServices.Create;
  FWindowManager := TWindowManager.Current;
  FMotionManager := TAndroidMotionManager.Create;
  FTextInputManager := TAndroidTextInputManager.Create;

  Application := TApplication.Create(nil);
  FFirstRun := True;
  FRunning := False;
  FActivityListener := TFMXNativeActivityListener.Create;
  MainActivity.setListener(FActivityListener);
  FWakeMainThreadRunnable := TWakeMainThreadRunnable.Create;
  FLastOrientation := UndefinedOrientation;
  if DeviceManager.GetModel = 'Glass 1' then
    TPlatformServices.Current.GlobalFlags.Add(EnableGlassFPSWorkaround, True);

  RegisterServices;
  RegisterWakeMainThread;

  FIdleHandler := TMessageQueueIdleHandler.Create(Self);
  TJLooper.JavaClass.getMainLooper.getQueue.addIdleHandler(FIdleHandler);
end;

destructor TPlatformAndroid.Destroy;
begin
  TJLooper.JavaClass.getMainLooper.getQueue.removeIdleHandler(FIdleHandler);
  FIdleHandler.Free;

  FTextInputManager.Free;
  FMotionManager.Free;
  FWindowManager.Free;
  FGraphicServices.Free;
  FVirtualKeyboardService.Free;
  FDeviceServices.Free;
  FMetricsServices.Free;
  FScreenServices.Free;
  FSaveStateService.Free;
  FTimerService.Free;
  FLoggerService.Free;
  UnregisterServices;
  UnbindAppGlueEvents;

  FWakeMainThreadRunnable := nil;
  FActivityListener.DisposeOf;
  UnregisterWakeMainThread;
  inherited;
end;

procedure TPlatformAndroid.Run;
begin
  FRunning := True;
  { Although calling this routine is not really necessary, but it is a way to ensure that "Androidapi.AppGlue.pas" is
    kept in uses list, in order to export ANativeActivity_onCreate callback. }
  app_dummy;
  InternalProcessMessages;
end;

function TPlatformAndroid.Running: Boolean;
begin
  Result := FRunning;
end;

function TPlatformAndroid.Terminating: Boolean;
begin
  Result := FTerminating;
end;

procedure TPlatformAndroid.Terminate;
begin
  FRunning := False;
  FTerminating := True;
  TMessageManager.DefaultManager.SendMessage(nil, TApplicationTerminatingMessage.Create);
  // When we manually finish our activity, Android will not generate OnSaveInstanceState event, because it is generated 
  // only in cases when the system is going to kill our activity to reclaim resources. In this particular case we 
  // initiate correct termination of the application, so we have to invoke OnSaveInstanceState manually to make sure 
  // that TForm.OnSaveState is invoked before the application is closed
  HandleApplicationCommandEvent(TAndroidApplicationGlue.Current, TAndroidApplicationCommand.SaveState);
  ANativeActivity_finish(System.DelphiActivity);
end;

function TPlatformAndroid.HandleAndroidInputEvent(const App: TAndroidApplicationGlue; const AEvent: PAInputEvent): Int32;
var
  EventType: Int64;
begin
  EventType := AInputEvent_getType(AEvent);

  if EventType = AINPUT_EVENT_TYPE_KEY then
    // Keyboard input
    Result := TextInputManager.HandleAndroidKeyEvent(AEvent)
  else if EventType = AINPUT_EVENT_TYPE_MOTION then
    // Motion Event
    Result := MotionManager.HandleAndroidMotionEvent(AEvent)
  else
    Result := 0;
end;

function TPlatformAndroid.HandleMessage: Boolean;
begin
  InternalProcessMessages;
  Result := False;
end;

procedure TPlatformAndroid.BindAppGlueEvents;
var
  AndroidAppGlue: TAndroidApplicationGlue;
begin
  AndroidAppGlue := PANativeActivity(System.DelphiActivity)^.instance;
  AndroidAppGlue.OnApplicationCommandEvent := HandleApplicationCommandEvent;
  AndroidAppGlue.OnContentRectEvent := HandleContentRectChanged;
  AndroidAppGlue.OnInputEvent := HandleAndroidInputEvent;
end;

procedure TPlatformAndroid.CheckOrientationChange;
var
  LOrientation: TScreenOrientation;
begin
  LOrientation := ScreenManager.GetScreenOrientation;
  if FLastOrientation <> LOrientation then
  begin
    FLastOrientation := LOrientation;
    TMessageManager.DefaultManager.SendMessage(Self, TOrientationChangedMessage.Create, True);
  end;
end;

procedure TPlatformAndroid.WaitMessage;
begin
  InternalProcessMessages;
end;

procedure TPlatformAndroid.RegisterWakeMainThread;
begin
  System.Classes.WakeMainThread := WakeMainThread;
end;

procedure TPlatformAndroid.UnregisterWakeMainThread;
begin
  System.Classes.WakeMainThread := nil;
end;

{ TWakeMainThreadRunnable }

procedure TWakeMainThreadRunnable.run;
begin
  PlatformAndroid.InternalProcessMessages;
end;

procedure TPlatformAndroid.WakeMainThread(Sender: TObject);
begin
  TAndroidHelper.Activity.runOnUiThread(FWakeMainThreadRunnable);
end;

procedure TPlatformAndroid.InternalProcessMessages;
var
  LDone: Boolean;
begin
  CheckSynchronize;

  //fix by swish
  FTimerService.ProcessQueueTimers;
  WindowManager.RenderIfNeeds;
  if not Terminating then
    try
      LDone := False;
      Application.DoIdle(LDone);
    except
      Application.HandleException(Application);
    end;
end;

function TPlatformAndroid.GetDefaultTitle: string;
begin
  Result := TAndroidHelper.ApplicationTitle;
end;

function TPlatformAndroid.GetTitle: string;
begin
  Result := FTitle;
end;

function TPlatformAndroid.GetVersionString: string;
var
  PackageInfo: JPackageInfo;
  PackageManager: JPackageManager;
  AppContext: JContext;
begin
  AppContext := TAndroidHelper.Context;
  if AppContext <> nil then
  begin
    PackageManager := AppContext.getPackageManager;
    if PackageManager <> nil then
    begin
      PackageInfo := AppContext.getPackageManager.getPackageInfo(AppContext.getPackageName, 0);
      if PackageInfo <> nil then
        Exit(JStringToString(PackageInfo.versionName));
    end;
  end;
  Result := string.Empty;
end;

procedure TPlatformAndroid.SetTitle(const Value: string);
begin
  FTitle := Value;
end;

procedure TPlatformAndroid.SetApplicationEventHandler(AEventHandler: TApplicationEventHandler);
begin
  FOnApplicationEvent := AEventHandler;
end;

function TPlatformAndroid.HandleApplicationEvent(AEvent: TApplicationEvent): Boolean;
var
  ApplicationEventMessage: TApplicationEventMessage;
begin
  Result := False;

  { Send broadcast message }
  ApplicationEventMessage := TApplicationEventMessage.Create(TApplicationEventData.Create(AEvent, nil));
  TMessageManager.DefaultManager.SendMessage(nil, ApplicationEventMessage);

  { Invoke application event}
  if Assigned(FOnApplicationEvent) then
    try
      Result := FOnApplicationEvent(AEvent, nil);
    except
      Application.HandleException(Self);
    end;
end;

procedure TPlatformAndroid.HandleContentRectChanged(const App: TAndroidApplicationGlue; const ARect: TRect);
begin
  TWindowManager.Current.ContentRect := ARect;
end;

procedure TPlatformAndroid.HandleApplicationCommandEvent(const App: TAndroidApplicationGlue; const ACommand: TAndroidApplicationCommand);
begin
  case ACommand of
    TAndroidApplicationCommand.Start:
      begin
        FRunning := True;
        FTerminating := False;
      end;

    TAndroidApplicationCommand.Resume:
      begin
       TWindowManager.Current.Pause := False;
       HandleApplicationEvent(TApplicationEvent.WillBecomeForeground);
       //add by Zeus64
       if not (TAndroidApplicationCommand.LostFocus in FPreviousActivityCommands) then HandleApplicationEvent(TApplicationEvent.BecameActive); // << https://quality.embarcadero.com/browse/RSP-18686
      end;

    TAndroidApplicationCommand.Pause:
      begin
        TWindowManager.Current.Pause := True;
       //add by Zeus64
        if not (TAndroidApplicationCommand.LostFocus in FPreviousActivityCommands) then HandleApplicationEvent(TApplicationEvent.WillBecomeInactive); // << https://quality.embarcadero.com/browse/RSP-18686
        HandleApplicationEvent(TApplicationEvent.EnteredBackground);
      end;

    TAndroidApplicationCommand.InitWindow:
    begin
      if FFirstRun then
      begin
        //fix by 爱吃猪头肉
        //fix for some device can not see StatueBar Text. etc Cool1 Dual.
        //It made StatueBar Color to BLACK.
        //you can uses following code to Set StatueBar Color to Device Default.
        //TAndroidHelper.Activity.getWindow.addFlags(
        //  TJWindowManager_LayoutParams.JavaClass.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        //TAndroidHelper.Activity.getWindow.setStatusBarColor(-1);
//[Android] Some device can not see StatueBar Text. etc Cool1 Dual.
//Some device can not see StatueBar Text.
//BackgroundColor and TextColor both is White.
//so cannot see anything.
        if TOSVersion.Check(6) then
        begin
          CallInUIThread(procedure () begin
            try
              if TAndroidHelper.Activity.getWindow <> nil then
              begin
                TAndroidHelper.Activity.getWindow.clearFlags(
                  TJWindowManager_LayoutParams.JavaClass.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
              end;
            except
            end;
          end);
        end;
        Application.RealCreateForms;
        FFirstRun := False;
        HandleApplicationEvent(TApplicationEvent.FinishedLaunching);
      end
      else
        Include(FPreviousActivityCommands, TAndroidApplicationCommand.InitWindow);
      TWindowManager.Current.InitWindow;
    end;

    TAndroidApplicationCommand.TermWindow:
      TWindowManager.Current.TermWindow;

    TAndroidApplicationCommand.WindowRedrawNeeded:
      TWindowManager.Current.SetNeedsRender;

    TAndroidApplicationCommand.GainedFocus:
      begin
        Exclude(FPreviousActivityCommands, TAndroidApplicationCommand.LostFocus);
        TWindowManager.Current.RenderImmediately;
        HandleApplicationEvent(TApplicationEvent.BecameActive);
        TWindowManager.Current.GainedFocus;
      end;

    TAndroidApplicationCommand.LostFocus:
      begin
        //add by Zeus64
        if not TWindowManager.Current.Pause then HandleApplicationEvent(TApplicationEvent.WillBecomeInactive); // << https://quality.embarcadero.com/browse/RSP-18686
        FPreviousActivityCommands := [TAndroidApplicationCommand.LostFocus];
      end;

    TAndroidApplicationCommand.SaveState:
      TMessageManager.DefaultManager.SendMessage(Self, TSaveStateMessage.Create);

    TAndroidApplicationCommand.ConfigChanged:
      begin
        Include(FPreviousActivityCommands, TAndroidApplicationCommand.ConfigChanged);
        CheckOrientationChange;
      end;

    TAndroidApplicationCommand.LowMemory:
      PlatformAndroid.HandleApplicationEvent(TApplicationEvent.LowMemory);

    TAndroidApplicationCommand.Destroy:
      HandleApplicationEvent(TApplicationEvent.WillTerminate);
  end;
end;

procedure TPlatformAndroid.RegisterServices;
begin
  if not TPlatformServices.Current.SupportsPlatformService(IFMXApplicationService) then
    TPlatformServices.Current.AddPlatformService(IFMXApplicationService, Self);
  if not TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService) then
    TPlatformServices.Current.AddPlatformService(IFMXApplicationEventService, Self);
  if not TPlatformServices.Current.SupportsPlatformService(IFMXWindowService) then
    TPlatformServices.Current.AddPlatformService(IFMXWindowService, WindowManager);
  if not TPlatformServices.Current.SupportsPlatformService(IFMXMouseService) then
    TPlatformServices.Current.AddPlatformService(IFMXMouseService, MotionManager);
  if not TPlatformServices.Current.SupportsPlatformService(IFMXGestureRecognizersService) then
    TPlatformServices.Current.AddPlatformService(IFMXGestureRecognizersService, MotionManager);
  if not TPlatformServices.Current.SupportsPlatformService(IFMXTextService) then
    TPlatformServices.Current.AddPlatformService(IFMXTextService, FTextInputManager);
  if (FVirtualKeyboardService <> nil) and not TPlatformServices.Current.SupportsPlatformService(IFMXKeyMappingService) then
    TPlatformServices.Current.AddPlatformService(IFMXKeyMappingService, FTextInputManager);
end;

procedure TPlatformAndroid.UnbindAppGlueEvents;
var
  AndroidAppGlue: TAndroidApplicationGlue;
begin
  AndroidAppGlue := PANativeActivity(System.DelphiActivity)^.instance;
  if AndroidAppGlue <> nil then
  begin
    AndroidAppGlue.OnApplicationCommandEvent := nil;
    AndroidAppGlue.OnContentRectEvent := nil;
    AndroidAppGlue.OnInputEvent := nil;
  end;
end;

procedure TPlatformAndroid.UnregisterServices;
begin
  TPlatformServices.Current.RemovePlatformService(IFMXApplicationService);
  TPlatformServices.Current.RemovePlatformService(IFMXApplicationEventService);
  TPlatformServices.Current.RemovePlatformService(IFMXWindowService);
  TPlatformServices.Current.RemovePlatformService(IFMXMouseService);
  TPlatformServices.Current.RemovePlatformService(IFMXGestureRecognizersService);
  TPlatformServices.Current.RemovePlatformService(IFMXTextService);
  TPlatformServices.Current.RemovePlatformService(IFMXKeyMappingService);
end;

{ TAndroidWindowHandle }

constructor TAndroidWindowHandle.Create(const AForm: TCommonCustomForm);
begin
  inherited Create;
  FNeedsUpdate := True;
  FForm := AForm;
  FBounds := TRectF.Create(AForm.Left, AForm.Top, AForm.Left + AForm.Width, AForm.Top + AForm.Height);
end;

procedure TAndroidWindowHandle.CreateTexture;
var
  ScaledSize: TSize;
begin
  if FTexture = nil then
  begin
    ScaledSize := TSize.Create(Round(Bounds.Width * TWindowManager.Current.Scale),
      Round(Bounds.Height * TWindowManager.Current.Scale));

    FTexture := TTexture.Create;
    FTexture.Style := [TTextureStyle.RenderTarget];
    FTexture.SetSize(ScaledSize.Width, ScaledSize.Height);
    FTexture.Initialize;
  end;
end;

procedure TAndroidWindowHandle.DestroyTexture;
begin
  if FTexture <> nil then
  begin
    FTexture.DisposeOf;
    FTexture := nil;
  end;
end;

procedure TAndroidWindowHandle.SetBounds(const Value: TRectF);
begin
  if FBounds <> Value then
  begin
    FBounds := Value;
    if FForm <> nil then
      FForm.SetBounds(Trunc(Value.Left), Trunc(Value.Top), Trunc(Value.Width), Trunc(Value.Height));
    TWindowManager.Current.SetNeedsRender;
  end;
end;

function TAndroidWindowHandle.GetBounds: TRectF;
begin
  Result := FBounds;
end;

function TAndroidWindowHandle.GetIsPopup: Boolean;
begin
  Result := PlatformAndroid.WindowManager.IsPopupForm(FForm);
end;

function TAndroidWindowHandle.GetScale: Single;
begin
  Result := TWindowManager.Current.Scale;
end;

function TAndroidWindowHandle.RequiresComposition: Boolean;
begin
  Result := PlatformAndroid.WindowManager.IsPopupForm(FForm) or (FForm.Transparency and (Application.MainForm <> FForm));
end;

procedure TAndroidWindowHandle.SetNeedsUpdate(const Value: Boolean);
begin
  FNeedsUpdate := Value;
  if FNeedsUpdate then
    TWindowManager.Current.SetNeedsRender;
end;

{ TTextServiceAndroid }

constructor TTextServiceAndroid.Create(const Owner: IControl; SupportMultiLine: Boolean);
begin
  FLines := TStringList.Create;
  FComposingBegin := -1;
  FComposingEnd := -1;
  inherited Create(Owner, SupportMultiLine);
end;

destructor TTextServiceAndroid.Destroy;
begin
  inherited;
end;

procedure TTextServiceAndroid.BeginSelection;
begin
  TWindowManager.Current.BeginSelection;
  TWindowManager.Current.HideContextMenu;
end;

procedure TTextServiceAndroid.EndSelection;
begin
  TWindowManager.Current.EndSelection;
  InternalUpdateSelection;
  TWindowManager.Current.ShowContextMenu;
end;

function TTextServiceAndroid.CombinedText: string;
var
  I, TextLength: Integer;
  Builder: TStringBuilder;
begin
  TextLength := 0;
  for I := 0 to FLines.Count - 1 do
  begin
    if I > 0 then
      Inc(TextLength);
    Inc(TextLength, FLines[I].Length);
  end;
  Builder := TStringBuilder.Create(TextLength);
  for I := 0 to FLines.Count - 1 do
  begin
    if I > 0 then
      Builder.Append(FLines.LineBreak);
    Builder.Append(FLines[I]);
  end;
  Result := Builder.ToString;
end;

procedure TTextServiceAndroid.CopySelectedText;
begin
  if FTextView <> nil then
    FTextView.copySelectedText;
end;

procedure TTextServiceAndroid.CutSelectedText;
begin
  if FTextView <> nil then
    FTextView.cutSelectedText;
end;

procedure TTextServiceAndroid.PasteText;
begin
  if FTextView <> nil then
    FTextView.pasteText;
end;

procedure TTextServiceAndroid.DrawSingleLine(const Canvas: TCanvas; const ARect: TRectF; const FirstVisibleChar: integer;
  const Font: TFont; const AOpacity: Single; const Flags: TFillTextFlags; const ATextAlign: TTextAlign;
  const AVTextAlign: TTextAlign = TTextAlign.Center; const AWordWrap: Boolean = False);
var
  I, Shift: Integer;
  S: string;
  Layout: TTextLayout;
  Region: TRegion;
begin
  Layout := TTextLayoutManager.TextLayoutByCanvas(Canvas.ClassType).Create;
  try
    Layout.BeginUpdate;
    Layout.TopLeft := ARect.TopLeft;
    Layout.MaxSize := PointF(ARect.Width, ARect.Height);
    Layout.WordWrap := AWordWrap;
    Layout.HorizontalAlign := ATextAlign;
    Layout.VerticalAlign := AVTextAlign;
    Layout.Font := Font;
    Layout.Color := Canvas.Fill.Color;
    Layout.Opacity := AOpacity;
    Layout.RightToLeft := TFillTextFlag.RightToLeft in Flags;
    if FLines.Count > 0 then
      S := FLines[FCaretPosition.Y]
    else
      S := '';
    Layout.Text := S.Substring(FirstVisibleChar - 1, S.Length - FirstVisibleChar + 1);
    Layout.EndUpdate;
    Layout.RenderLayout(Canvas);

    if (FComposingBegin >= 0) and (FComposingEnd >= 0) and (FComposingBegin < FComposingEnd) and IsFocused then
    try
      Shift := 0;
      if FLines.Count > 0 then
        for I := 0 to FCaretPosition.Y - 1 do
          Inc(Shift, FLines[I].Length + FLines.LineBreak.Length);

      Canvas.Stroke.Assign(Canvas.Fill);
      Canvas.Stroke.Thickness := 1;
      Canvas.Stroke.Dash := TStrokeDash.Solid;

      Region := Layout.RegionForRange(TTextRange.Create(FComposingBegin - Shift - (FirstVisibleChar - 1), FComposingEnd - FComposingBegin));
      for I := Low(Region) to High(Region) do
        Canvas.DrawLine(
          PointF(Region[I].Left, Region[I].Bottom),
          PointF(Region[I].Right, Region[I].Bottom),
          AOpacity, Canvas.Stroke);
    finally
    end;
  finally
    FreeAndNil(Layout);
  end;
end;

procedure TTextServiceAndroid.DrawSingleLine(const Canvas: TCanvas; const S: string; const ARect: TRectF; const Font: TFont;
  const AOpacity: Single; const Flags: TFillTextFlags; const ATextAlign: TTextAlign;
  const AVTextAlign: TTextAlign = TTextAlign.Center; const AWordWrap: Boolean = False);
var
  I: Integer;
  Layout: TTextLayout;
  Region: TRegion;
begin
  Layout := TTextLayoutManager.TextLayoutByCanvas(Canvas.ClassType).Create;
  try
    Layout.BeginUpdate;
    Layout.TopLeft := ARect.TopLeft;
    Layout.MaxSize := PointF(ARect.Width, ARect.Height);
    Layout.WordWrap := AWordWrap;
    Layout.HorizontalAlign := ATextAlign;
    Layout.VerticalAlign := AVTextAlign;
    Layout.Font := Font;
    Layout.Color := Canvas.Fill.Color;
    Layout.Opacity := AOpacity;
    Layout.RightToLeft := TFillTextFlag.RightToLeft in Flags;
    Layout.Text := S;
    Layout.EndUpdate;
    Layout.RenderLayout(Canvas);

    if (FComposingBegin >= 0) and (FComposingEnd >= 0) and (FComposingBegin < FComposingEnd) then
    try
      Canvas.Stroke.Assign(Canvas.Fill);
      Canvas.Stroke.Thickness := 1;
      Canvas.Stroke.Dash := TStrokeDash.Solid;

      Region := Layout.RegionForRange(TTextRange.Create(FComposingBegin, FComposingEnd - FComposingBegin));
      for I := Low(Region) to High(Region) do
        Canvas.DrawLine(
          PointF(Region[I].Left, Region[I].Bottom),
          PointF(Region[I].Right, Region[I].Bottom),
          AOpacity, Canvas.Stroke);
    finally
    end;
  finally
    FreeAndNil(Layout);
  end;
end;

{ TFMXTextListener }

constructor TFMXTextListener.Create(const TextService: TTextServiceAndroid);
begin
  inherited Create;
  FTextService := TextService;
end;

procedure TFMXTextListener.onTextUpdated(text: JCharSequence; position: Integer);
begin
  TWindowManager.Current.HideContextMenu;
  FTextService.ProcessUpdate(position, JCharSequenceToStr(text));
  PlatformAndroid.InternalProcessMessages;
end;

procedure TFMXTextListener.onComposingText(beginPosition: Integer; endPosition: Integer);
begin
  TWindowManager.Current.HideContextMenu;
  FTextService.FComposingBegin := beginPosition;
  FTextService.FComposingEnd := endPosition;
end;

procedure TFMXTextListener.onSkipKeyEvent(event: JKeyEvent);
begin
  PlatformAndroid.TextInputManager.SetKeyboardEventToSkip(event);
end;

procedure TTextServiceAndroid.EnterControl(const FormHandle: TWindowHandle);
var
  VirtKBControl: IVirtualKeyboardControl;
  KbType: Integer;
  RKType: Integer;
  SelStart, SelEnd: Integer;
  ReadOnly, Password: Boolean;
  LReadOnly: IReadOnly;
begin
  if (FormHandle is TAndroidWindowHandle) and (TAndroidWindowHandle(FormHandle).Form.Focused <> nil) then
  begin
    if Supports(TAndroidWindowHandle(FormHandle).Form.Focused, IVirtualKeyboardControl, VirtKBControl) then
    begin
      TWindowManager.Current.FIsFirstSingleTap := True;
      TWindowManager.Current.SetFocusedControl(TAndroidWindowHandle(FormHandle).Form.Focused);
	  
      case VirtKBControl.ReturnKeyType of
        TReturnKeyType.Default:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_ENTER;
        TReturnKeyType.Done:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_DONE;
        TReturnKeyType.Go:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_GO;
        TReturnKeyType.Next:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_NEXT;
        TReturnKeyType.Search:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_SEARCH;
        TReturnKeyType.Send:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_SEND;
      else
        RKType := TJFMXTextEditorProxy.JavaClass.ACTION_ENTER;
      end;

      case VirtKBControl.KeyboardType of
        TVirtualKeyboardType.Default:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_TEXT;
        TVirtualKeyboardType.NumbersAndPunctuation:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_NUMBER_AND_PUNCTUATION;
        TVirtualKeyboardType.NumberPad:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_NUMBER;
        TVirtualKeyboardType.PhonePad:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_PHONE;
        TVirtualKeyboardType.Alphabet:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_ALPHABET;
        TVirtualKeyboardType.URL:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_URL;
        TVirtualKeyboardType.NamePhonePad:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_NAME_PHONE_PAD;
        TVirtualKeyboardType.EmailAddress:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_EMAIL_ADDRESS;
        TVirtualKeyboardType.DecimalNumberPad:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_NUMBER_DECIMAL;
      else
        KbType := TJFMXTextEditorProxy.JavaClass.INPUT_TEXT;
      end;
      Password := VirtKBControl.IsPassword;
    end
    else
    begin
      KbType := TJFMXTextEditorProxy.JavaClass.INPUT_TEXT;
      RKType := TJFMXTextEditorProxy.JavaClass.ACTION_ENTER;
      Password := False;
    end;

    if Supports(TAndroidWindowHandle(FormHandle).Form.Focused, IReadOnly, LReadOnly) then
    try
      ReadOnly := LReadOnly.ReadOnly;
    finally
      LReadOnly := nil;
    end
    else
      ReadOnly := True;

    if FTextView = nil then
      FTextView := PlatformAndroid.TextInputManager.GetTextEditorProxy;

    if FTextView <> nil then
    begin
      if FTextListener = nil then
        FTextListener := TFMXTextListener.Create(Self);
      CalculateSelectionBounds(SelStart, SelEnd);
      FTextView.setMaxLength(MaxLength);
      case CharCase of
        TEditCharCase.ecUpperCase:
          FTextView.setCharCase(TJFMXTextEditorProxy.JavaClass.CHARCASE_UPPER);
        TEditCharCase.ecLowerCase:
          FTextView.setCharCase(TJFMXTextEditorProxy.JavaClass.CHARCASE_LOWER);
      else
        FTextView.setCharCase(TJFMXTextEditorProxy.JavaClass.CHARCASE_NORMAL);
      end;
      FTextView.setFilterChar(StrToJCharSequence(FilterChar));
      FTextView.setMultiline(MultiLine);
      FTextView.setReadOnly(ReadOnly);
      FTextView.setInputType(KbType);
      FTextView.setIsPassword(Password);
      FTextView.setText(StrToJCharSequence(FText));
      FTextView.setEnterAction(RKType);
      if SelEnd - SelStart > 0 then
        FTextView.setSelection(SelStart, SelEnd)
      else
        FTextView.setCursorPosition(CaretPosition.X);
      FTextView.addTextListener(FTextListener);
      MainActivity.getViewStack.addView(nil);
      FTextView.setFocusableInTouchMode(true);
      FTextView.requestFocus;
      FTextView.showSoftInput(True);
    end;

    TMessageManager.DefaultManager.SubscribeToMessage(TVKStateChangeMessage, HandleVK);
  end;
end;

procedure TTextServiceAndroid.ExitControl(const FormHandle: TWindowHandle);
begin
  TMessageManager.DefaultManager.Unsubscribe(TVKStateChangeMessage, HandleVK);
  if (FTextView <> nil) and (FTextListener <> nil) then
  begin
    FComposingBegin := -1;
    FComposingEnd := -1;
    FTextView.setCursorPosition(FCaretPosition.X);
    FTextView.removeTextListener(FTextListener);
    FTextView.clearFocus;
    FTextView := nil;
    TWindowManager.Current.HideContextMenu;
    FTextListener := nil;
  end;
end;

function TTextServiceAndroid.GetCaretPostion: TPoint;
begin
  Result := FCaretPosition;
end;

procedure TTextServiceAndroid.SetCaretPosition(const Value: TPoint);
var
  SelStart, SelEnd: Integer;
begin
  FCaretPosition := Value;
  CalculateSelectionBounds(SelStart, SelEnd);
  if (FTextView <> nil) and not FInternalUpdate then
    if (SelEnd - SelStart) > 0 then
      FTextView.setSelection(SelStart, SelEnd)
    else
      FTextView.setCursorPosition(CaretPosition.X);
end;

procedure TTextServiceAndroid.SetMaxLength(const Value: Integer);
begin
  inherited;
  if FTextView <> nil then
    FTextView.setMaxLength(Value);
end;

procedure TTextServiceAndroid.SetCharCase(const Value: TEditCharCase);
begin
  inherited;
  if FTextView <> nil then
    case Value of
      TEditCharCase.ecUpperCase:
        FTextView.setCharCase(TJFMXTextEditorProxy.JavaClass.CHARCASE_UPPER);
      TEditCharCase.ecLowerCase:
        FTextView.setCharCase(TJFMXTextEditorProxy.JavaClass.CHARCASE_LOWER);
    else
      FTextView.setCharCase(TJFMXTextEditorProxy.JavaClass.CHARCASE_NORMAL);
    end;
end;

procedure TTextServiceAndroid.SetFilterChar(const Value: string);
begin
  inherited;
  if FTextView <> nil then
    FTextView.setFilterChar(StrToJCharSequence(Value));
end;

function TTextServiceAndroid.GetText: string;
begin
  Result := FText;
end;

procedure TTextServiceAndroid.SetText(const Value: string);
begin
  if not SameStr(FText, Value) then
  begin
    FText := Value;
    UnpackText;
    if FTextView <> nil then
      FTextView.setText(StrToJCharSequence(Value));
  end;
end;

procedure TTextServiceAndroid.HandleVK(const Sender: TObject; const M: TMessage);
var
  VirtKBControl: IVirtualKeyboardControl;
  KbType: Integer;
  RKType: Integer;
  LReadOnly: IReadOnly;
  ReadOnly, Password: Boolean;
begin
  if (FTextView <> nil) and (Screen.ActiveForm <> nil) and (Screen.ActiveForm.Focused <> nil) and
    TVKStateChangeMessage(M).KeyboardVisible then
  begin
    if Supports(Screen.ActiveForm.Focused, IVirtualKeyboardControl, VirtKBControl) then
    begin
      case VirtKBControl.ReturnKeyType of
        TReturnKeyType.Default:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_ENTER;
        TReturnKeyType.Done:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_DONE;
        TReturnKeyType.Go:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_GO;
        TReturnKeyType.Next:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_NEXT;
        TReturnKeyType.Search:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_SEARCH;
        TReturnKeyType.Send:
          RKType := TJFMXTextEditorProxy.JavaClass.ACTION_SEND;
      else
        RKType := TJFMXTextEditorProxy.JavaClass.ACTION_ENTER;
      end;

      case VirtKBControl.KeyboardType of
        TVirtualKeyboardType.Default:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_TEXT;
        TVirtualKeyboardType.NumbersAndPunctuation:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_NUMBER_AND_PUNCTUATION;
        TVirtualKeyboardType.NumberPad:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_NUMBER;
        TVirtualKeyboardType.PhonePad:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_PHONE;
        TVirtualKeyboardType.Alphabet:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_ALPHABET;
        TVirtualKeyboardType.URL:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_URL;
        TVirtualKeyboardType.NamePhonePad:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_NAME_PHONE_PAD;
        TVirtualKeyboardType.EmailAddress:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_EMAIL_ADDRESS;
        TVirtualKeyboardType.DecimalNumberPad:
          KbType := TJFMXTextEditorProxy.JavaClass.INPUT_NUMBER_DECIMAL;
      else
        KbType := TJFMXTextEditorProxy.JavaClass.INPUT_TEXT;
      end;
      Password := VirtKBControl.IsPassword;
    end
    else
    begin
      KbType := TJFMXTextEditorProxy.JavaClass.INPUT_TEXT;
      RKType := TJFMXTextEditorProxy.JavaClass.ACTION_ENTER;
      Password := False;
    end;

    if Supports(Screen.ActiveForm.Focused, IReadOnly, LReadOnly) then
    try
      ReadOnly := LReadOnly.ReadOnly;
    finally
      LReadOnly := nil;
    end
    else
      ReadOnly := False;

    FTextView.setReadOnly(ReadOnly);
    FTextView.setInputType(KbType);
    FTextView.setIsPassword(Password);
    FTextView.setEnterAction(RKType);
  end;
end;

function TTextServiceAndroid.HasMarkedText: Boolean;
begin
  Result := (FComposingBegin >= 0) and (FComposingEnd >= 0) and (FComposingBegin < FComposingEnd);
end;

function TTextServiceAndroid.GetImeMode: TImeMode;
begin
  Result := FImeMode;
end;

procedure TTextServiceAndroid.CalculateSelectionBounds(out SelectionStart, SelectionEnd: Integer);
var
  TextInput: ITextInput;
  I: Integer;
  SelBounds: TRect;
  TopLeft, BottomRight: TPoint;
begin
  if (FLines <> nil) and Supports(Owner, ITextInput, TextInput) then
  begin
    if FLines.Count > 0 then
    begin
      SelBounds := TextInput.GetSelectionBounds;
      if (SelBounds.Top > SelBounds.Bottom) or ((SelBounds.Height = 0) and (SelBounds.Left > SelBounds.Right)) then
      begin
        TopLeft := SelBounds.BottomRight;
        BottomRight := SelBounds.TopLeft;
      end
      else
      begin
        TopLeft := SelBounds.TopLeft;
        BottomRight := SelBounds.BottomRight;
      end;

      SelectionStart := TopLeft.X;
      for I := 0 to Min(TopLeft.Y - 1, FLines.Count - 1) do
        Inc(SelectionStart, FLines[I].Length + FLines.LineBreak.Length);
      SelectionEnd := SelBounds.Right + (SelectionStart - SelBounds.Left);
      for I := Min(TopLeft.Y, FLines.Count - 1) to Min(BottomRight.Y - 1, FLines.Count - 1) do
        Inc(SelectionEnd, FLines[I].Length + FLines.LineBreak.Length);
    end
    else
    begin
      SelectionStart := Min(SelBounds.Left, SelBounds.Right);
      SelectionEnd := Max(SelBounds.Left, SelBounds.Right);
    end
  end
  else
  begin
    SelectionStart := FCaretPosition.X;
    SelectionEnd := FCaretPosition.X;
  end;
end;

procedure TTextServiceAndroid.SetImeMode(const Value: TImeMode);
begin
  FImeMode := Value;
end;

procedure TTextServiceAndroid.InternalUpdate;
begin
  FInternalUpdate := True;
  try
    (Owner as ITextInput).IMEStateUpdated;
  finally
    FInternalUpdate := False;
  end;
end;

procedure TTextServiceAndroid.InternalUpdateSelection;
var
  SelStart, SelEnd: Integer;
begin
  CalculateSelectionBounds(SelStart, SelEnd);
  if FTextView <> nil then
    FTextView.setSelection(SelStart, SelEnd);
end;

function TTextServiceAndroid.IsFocused: Boolean;
begin
  Result := False;
  if FTextView <> nil then
    Result := FTextView.isFocused;
end;

procedure TTextServiceAndroid.ProcessUpdate(const APos: Integer; AText: string);
begin
  FText := AText;
  UnpackText;
  FCaretPosition.X := APos;
  PostProcessUpdate;
end;

procedure TTextServiceAndroid.PostProcessUpdate;
begin
  InternalUpdate;
end;

function TTextServiceAndroid.TargetClausePosition: TPoint;
begin
  Result := CaretPosition;
end;

procedure TTextServiceAndroid.UnpackText;
var
  HeaderBegin, HeaderEnd: Integer;
  LinesLength: TArray<string>;
  I, LineLength, LengthBefore: Integer;
begin
  FLines.Clear;
  HeaderBegin := FText.IndexOf('[');
  HeaderEnd := FText.IndexOf(']');
  if not FText.IsEmpty and (HeaderBegin >= 0) and (HeaderEnd > 0) then
  begin
    LinesLength := FText.Substring(HeaderBegin + 1, HeaderEnd - HeaderBegin - 1).Split([',']);
    LengthBefore := 0;
    for I := 0 to Length(LinesLength) - 1 do
    begin
      LineLength := StrToInt(LinesLength[I]);
      if LineLength > 0 then
        FLines.Add(FText.Substring(HeaderEnd + 1 + LengthBefore, LineLength))
      else
        FLines.Add(string.Empty);
      Inc(LengthBefore, LineLength);
    end;
  end;
end;

{ TFMXNativeActivityListener }

procedure TFMXNativeActivityListener.onCancelReceiveImage(ARequestCode: Integer);
begin
  TThread.Queue(nil, procedure
  begin
    TMessageManager.DefaultManager.SendMessage(nil, TMessageCancelReceivingImage.Create(ARequestCode));
  end);
end;

procedure TFMXNativeActivityListener.onReceiveImagePath(ARequestCode: Integer; AFileName: JString);
var
  Message: TMessageReceivedImagePath;
begin
  TThread.Queue(nil, procedure
  var
    ImageFileName: string;
  begin
    ImageFileName := JStringToString(AFileName);
    Message := TMessageReceivedImagePath.Create(ImageFileName);
    Message.RequestCode := ARequestCode;
    TMessageManager.DefaultManager.SendMessage(nil, Message);
  end);
end;

procedure TFMXNativeActivityListener.onReceiveNotification(P1: JIntent);
begin
  TMessageManager.DefaultManager.SendMessage(nil, TMessageReceivedNotification.Create(P1));
end;

procedure TFMXNativeActivityListener.onReceiveResult(ARequestCode, AResultCode: Integer; AResultObject: JIntent);
var
  Msg: TMessageResultNotification;
begin
  Msg := TMessageResultNotification.Create(AResultObject);
  Msg.RequestCode := ARequestCode;
  Msg.ResultCode := AResultCode;
  TMessageManager.DefaultManager.SendMessage(nil, Msg);
end;

function ConvertPixelToPoint(const P: TPointF): TPointF;
begin
  Result := TWindowManager.Current.PixelToPoint(P);
end;

function ConvertPointToPixel(const P: TPointF): TPointF;
begin
  Result := TWindowManager.Current.PointToPixel(P);
end;

{ TAndroidMotionManager }

procedure TAndroidMotionManager.AddRecognizer(const AGesture: TInteractiveGesture; const AForm: TCommonCustomForm);
begin
  Include(FEnabledInteractiveGestures, AGesture);
end;

constructor TAndroidMotionManager.Create;
begin
  inherited;
  FMotionEvents := TMotionEvents.Create;
end;

procedure TAndroidMotionManager.CreateDoubleTapTimer;
begin
  if FDoubleTapTimer = 0 then
    FDoubleTapTimer := PlatformAndroid.TimerManager.CreateTimer(DblTapDelay, DoubleTapTimerCall);
end;

function TAndroidMotionManager.CreateGestureEventInfo(ASecondPointer: TPointF; const AGesture: TInteractiveGesture;
  const AGestureEnded: Boolean): TGestureEventInfo;
begin
  FillChar(Result, Sizeof(Result), 0);
  Result.Location := FMouseCoord;
  Result.GestureID := igiZoom + Ord(AGesture);

  if not(AGesture in FActiveInteractiveGestures) then
    Result.Flags := [TInteractiveGestureFlag.gfBegin];
  if AGestureEnded then
    Result.Flags := [TInteractiveGestureFlag.gfEnd];

  if AGesture = TInteractiveGesture.LongTap then
    Result.Location := FMouseDownCoordinates;
end;

procedure TAndroidMotionManager.CreateLongTapTimer;
begin
  if FLongTapTimer = 0  then
    FLongTapTimer := PlatformAndroid.TimerManager.CreateTimer(LongTapDuration, LongTapTimerCall);
end;

procedure TAndroidMotionManager.CreateSingleTapTimer;
begin
  if FSingleTapTimer = 0 then
    FSingleTapTimer := PlatformAndroid.TimerManager.CreateTimer(SingleTapDelay, SingleTapTimerCall);
end;

destructor TAndroidMotionManager.Destroy;
begin
  DestroyDoubleTapTimer;
  DestroyLongTapTimer;
  DestroySingleTapTimer;
  FMotionEvents.Free;
  inherited;
end;

procedure TAndroidMotionManager.DestroyDoubleTapTimer;
begin
  if FDoubleTapTimer <> 0 then
    PlatformAndroid.TimerManager.DestroyTimer(FDoubleTapTimer);
  FDoubleTapTimer := 0;
  FDblClickFirstMouseUp := False;
end;

procedure TAndroidMotionManager.DestroyLongTapTimer;
begin
  if FLongTapTimer <> 0 then
    PlatformAndroid.TimerManager.DestroyTimer(FLongTapTimer);
  FLongTapTimer := 0;
end;

procedure TAndroidMotionManager.DestroySingleTapTimer;
begin
  if FSingleTapTimer <> 0 then
    PlatformAndroid.TimerManager.DestroyTimer(FSingleTapTimer);
  FSingleTapTimer := 0;
  FSingletap := False;
end;

procedure TAndroidMotionManager.DoubleTapTimerCall;
begin
  //no double tap was made
  DestroyDoubleTapTimer;
end;

function TAndroidMotionManager.GetLongTapAllowedMovement: Single;
begin
  Result := LongTapMovement / TWindowManager.Current.Scale;
end;

function TAndroidMotionManager.GetMousePos: TPointF;
begin
  Result := FMouseCoord;
end;

function TAndroidMotionManager.HandleAndroidMotionEvent(AEvent: PAInputEvent): Int32;
var
  I: Integer;
  MotionEvent: TMotionEvent;
begin
  Result := 0;

  FMotionEvents.Clear;
  for I := 0 to AMotionEvent_getPointerCount(AEvent) - 1 do
  begin
    MotionEvent.EventAction := AKeyEvent_getAction(AEvent) and AMOTION_EVENT_ACTION_MASK;
    MotionEvent.Position := TWindowManager.Current.PixelToPoint(TPointF.Create(AMotionEvent_getX(AEvent, I),
      AMotionEvent_getY(AEvent, I)));
    MotionEvent.Shift := [ssLeft];
    if AInputEvent_getType(AEvent) <> AINPUT_SOURCE_MOUSE then
      Include(MotionEvent.Shift, ssTouch);
    FMotionEvents.Add(MotionEvent);
  end;

  HandleMultiTouch;

  if (FActiveInteractiveGestures = []) or (FActiveInteractiveGestures = [TInteractiveGesture.Pan]) then
    ProcessAndroidMouseEvents;
  ProcessAndroidGestureEvents;
end;

procedure TAndroidMotionManager.HandleMultiTouch;
var
  Touches: TTouches;
  TouchAction: TTouchAction;
  I: Integer;
begin
  if FMotionEvents.Count > 0 then
  begin
    SetLength(Touches, FMotionEvents.Count);
    for I := 0 to FMotionEvents.Count - 1 do
      Touches[I].Location := FMotionEvents[I].Position;

    case FMotionEvents[0].EventAction of
      AMOTION_EVENT_ACTION_DOWN:
        TouchAction := TTouchAction.Down;
      AMOTION_EVENT_ACTION_UP:
        TouchAction := TTouchAction.Up;
      AMOTION_EVENT_ACTION_MOVE:
        TouchAction := TTouchAction.Move;
      AMOTION_EVENT_ACTION_CANCEL:
        TouchAction := TTouchAction.Cancel;
      AMOTION_EVENT_ACTION_POINTER_DOWN:
        TouchAction := TTouchAction.Down;
      AMOTION_EVENT_ACTION_POINTER_UP:
        TouchAction := TTouchAction.Up;
      else
      begin
        TouchAction := TTouchAction.None;
      end;
    end;
    TWindowManager.Current.MultiTouch(Touches, TouchAction, FEnabledInteractiveGestures);
  end;
end;

procedure TAndroidMotionManager.LongTapTimerCall;
begin
  //a long press was recognized
  DestroyLongTapTimer;
  DestroySingleTapTimer;
  TWindowManager.Current.SendCMGestureMessage(CreateGestureEventInfo(PointF(0, 0), TInteractiveGesture.LongTap));
end;

procedure TAndroidMotionManager.ProcessAndroidGestureEvents;
var
  SecondPointer: TPointF;
begin
  if FMotionEvents.Count < 1 then
    Exit;

  FMouseCoord := FMotionEvents[0].Position;

  if FMotionEvents.Count > 1 then
    SecondPointer := FMotionEvents[1].Position
  else
    SecondPointer := TPointF.Zero;

  case (FMotionEvents[0].EventAction and AMOTION_EVENT_ACTION_MASK) of
    AMOTION_EVENT_ACTION_DOWN:
      begin
        if FSingleTapTimer <> 0 then
          DestroySingleTapTimer
        else
          FSingleTap := True;

        if FDoubleTapTimer = 0 then
          if (TInteractiveGesture.DoubleTap in FEnabledInteractiveGestures) and (FMotionEvents.Count = 1) then
            CreateDoubleTapTimer;

        if (TInteractiveGesture.LongTap in FEnabledInteractiveGestures)  and (FMotionEvents.Count = 1) then
          CreateLongTapTimer;
      end;
    AMOTION_EVENT_ACTION_UP:
      begin
        if FSingleTap then
          CreateSingleTapTimer;

        if FDoubleTapTimer <> 0 then
          if not FDblClickFirstMouseUp then
            FDblClickFirstMouseUp := True
          else
          begin
            DestroyDoubleTapTimer;
            FDblClickFirstMouseUp := False;
            TWindowManager.Current.SendCMGestureMessage(CreateGestureEventInfo(TPointF.Zero,
              TInteractiveGesture.DoubleTap));
          end;

        //stop longtap timer
        DestroyLongTapTimer;
      end;
    AMOTION_EVENT_ACTION_MOVE:
      begin
        // Stop longtap and double tap timers only if the coordinates did not change (much) since the last event.
        // Allow for some slight finger movement.
        if FMotionEvents.Count = 1 then
        begin
          if FMouseCoord.Distance(FMouseDownCoordinates) > GetLongTapAllowedMovement then
          begin
            DestroySingleTapTimer;
          end;

          if FMouseCoord.Distance(FOldPoint1) > GetLongTapAllowedMovement then
          begin
            DestroyLongTapTimer;
            DestroyDoubleTapTimer;
          end;

          FOldPoint2 := TPointF.Zero;
        end;
      end;
    AMOTION_EVENT_ACTION_CANCEL:
      begin
        DestroyLongTapTimer;
        DestroyDoubleTapTimer;
        DestroySingleTapTimer;
        FActiveInteractiveGestures := [];
        FRotationAngle := 0;
        FOldPoint1 := TPointF.Zero;
        FOldPoint2 := TPointF.Zero;
        FMouseDownCoordinates := TPointF.Zero;
      end;
    AMOTION_EVENT_ACTION_POINTER_DOWN:
      begin
        //stop timers
        DestroyLongTapTimer;
        DestroyDoubleTapTimer;
        DestroySingleTapTimer;
        if FMotionEvents.Count = 2 then
          FOldPoint2 := SecondPointer;
      end;
    AMOTION_EVENT_ACTION_POINTER_UP:
      begin
        //from 2 pointers now, there will be only 1 pointer
        if FMotionEvents.Count = 2 then
          FOldPoint2 := TPointF.Zero;
      end;
  end;

  FOldPoint1 := FMotionEvents[0].Position;
  FOldPoint2 := SecondPointer;
end;

procedure TAndroidMotionManager.ProcessAndroidMouseEvents;
var
  MotionEvent: TMotionEvent;
begin
  if FMotionEvents.Count > 0 then
  begin
    MotionEvent := FMotionEvents[0];

    case MotionEvent.EventAction of
      AMOTION_EVENT_ACTION_DOWN:
      begin
        TWindowManager.Current.MouseDown(TMouseButton.mbLeft, MotionEvent.Shift, MotionEvent.Position.X, MotionEvent.Position.Y);
        FMouseDownCoordinates := MotionEvent.Position;
      end;

      AMOTION_EVENT_ACTION_UP:
      begin
        TWindowManager.Current.MouseUp(TMouseButton.mbLeft, MotionEvent.Shift, MotionEvent.Position.X, MotionEvent.Position.Y, not FGestureEnded);
        FGestureEnded := False;
      end;

      AMOTION_EVENT_ACTION_MOVE:
        TWindowManager.Current.MouseMove(MotionEvent.Shift, MotionEvent.Position.X, MotionEvent.Position.Y);
    end;

    FMouseCoord := MotionEvent.Position;
  end;
end;

procedure TAndroidMotionManager.RemoveRecognizer(const AGesture: TInteractiveGesture; const AForm: TCommonCustomForm);
begin
  Exclude(FEnabledInteractiveGestures, AGesture);
end;

procedure TAndroidMotionManager.SingleTap;
begin
  TWindowManager.Current.SingleTap;
end;

procedure TAndroidMotionManager.SingleTapTimerCall;
begin
  DestroySingleTapTimer;
  SingleTap;
end;

{ TAndroidTextInputManager }

constructor TAndroidTextInputManager.Create;
var
  InputDeviceID: Integer;
begin
  inherited;
  TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, FVirtualKeyboard);
  FKeyMapping := TKeyMapping.Create;
  FSkipEventQueue := TQueue<JKeyEvent>.Create;
  if TOSVersion.Check(3, 0) then
    InputDeviceID := TJKeyCharacterMap.JavaClass.VIRTUAL_KEYBOARD
  else
    InputDeviceID := TJKeyCharacterMap.JavaClass.BUILT_IN_KEYBOARD;
  FKeyCharacterMap := TJKeyCharacterMap.JavaClass.load(InputDeviceID);
end;

destructor TAndroidTextInputManager.Destroy;
begin
  FSkipEventQueue.Free;
  FKeyMapping.Free;
  inherited;
end;

function TAndroidTextInputManager.GetTextEditorProxy: JFmxTextEditorProxy;
begin
  if FTextEditorProxy = nil then
    FTextEditorProxy := MainActivity.getTextEditorProxy;
  Result := FTextEditorProxy;
end;

function TAndroidTextInputManager.GetTextServiceClass: TTextServiceClass;
begin
  Result := TTextServiceAndroid;
end;

function TAndroidTextInputManager.HandleAndroidKeyEvent(AEvent: PAInputEvent): Int32;
var
  KeyCode, vkKeyCode: Word;
  Action, MetaState: Integer;
  KeyChar: Char;
  KeyEvent: JKeyEvent;
  KeyEventChars: string;
  C: WideChar;
  SkipEvent: JKeyEvent;
  LKeyDownHandled: Boolean;
  KeyKind: TKeyKind;
  EventTime, DownTime: Int64;
  DeviceId: Integer;
begin
  Result := 0;

  Action := AKeyEvent_getAction(AEvent);
  KeyCode := AKeyEvent_getKeyCode(AEvent);
  MetaState := AKeyEvent_getMetaState(AEvent);
  EventTime := AKeyEvent_getEventTime(AEvent) div 1000000;
  DownTime := AKeyEvent_getDownTime(AEvent) div 1000000;
  DeviceId := AInputEvent_getDeviceId(AEvent);

  if FSkipEventQueue.Count > 0 then
    SkipEvent := FSkipEventQueue.Peek
  else
    SkipEvent := nil;

  if (SkipEvent <> nil) and ((SkipEvent.getEventTime < EventTime) or (SkipEvent.getDownTime < DownTime)) then
  begin
    SkipEvent := nil;
    FSkipEventQueue.Dequeue;
  end;

  if (SkipEvent = nil) or (SkipEvent.getAction <> Action) or (SkipEvent.getFlags <> AKeyEvent_getFlags(AEvent)) or
    (SkipEvent.getKeyCode <> KeyCode) or (SkipEvent.getMetaState <> MetaState) or (SkipEvent.getEventTime <> EventTime) or
    (SkipEvent.getDownTime <> DownTime) then
  begin
    KeyChar := #0;

    vkKeyCode := PlatformKeyToVirtualKey(KeyCode, KeyKind);
    if (vkKeyCode <> 0) and (KeyKind <> TKeyKind.Usual) then
    begin
      KeyCode := vkKeyCode;
      if KeyCode in [vkEscape] then
        KeyChar := Char(KeyCode);
    end
    else
    begin
      if FKeyCharacterMap <> nil then
      begin
        KeyChar := Char(ObtainKeyCharacterMap(DeviceId).get(KeyCode, MetaState));
        if KeyChar <> #0 then
          KeyCode := 0
        else
          KeyCode := vkKeyCode;
      end;
    end;

    case AKeyEvent_getAction(AEvent) of
      AKEY_EVENT_ACTION_DOWN:
        begin
          if (KeyCode = vkHardwareBack) and (KeyChar = #0) and (FVirtualKeyboard <> nil) and
            (FVirtualKeyboard.VirtualKeyboardState * [TVirtualKeyboardState.Visible] <> []) then
          begin
            FDownKey := 0;
            FDownKeyChar := #0;
          end
          else
          begin
            FDownKey := KeyCode;
            FDownKeyChar := KeyChar;
            TWindowManager.Current.KeyDown(KeyCode, KeyChar, ShiftStateFromMetaState(MetaState));
          end;
          FKeyDownHandled := (KeyCode = 0) and (KeyChar = #0);
          if FKeyDownHandled then
            Result := 1;
        end;
      AKEY_EVENT_ACTION_UP:
        begin
          LKeyDownHandled := (FDownKey = KeyCode) and (FDownKeyChar = KeyChar) and FKeyDownHandled;
          TWindowManager.Current.KeyUp(KeyCode, KeyChar, ShiftStateFromMetaState(MetaState), LKeyDownHandled);
          if (KeyCode = 0) and (KeyChar = #0) then
            Result := 1; // indicate that we have handled the event
        end;
      AKEY_EVENT_ACTION_MULTIPLE:
        begin
          KeyEvent := JFMXNativeActivity(MainActivity).getLastEvent;
          if KeyEvent <> nil then
          begin
            KeyEventChars := JStringToString(KeyEvent.getCharacters);
            KeyCode := 0;
            for C in KeyEventChars do
            begin
              FDownKey := KeyCode;
              FDownKeyChar := C;
              TWindowManager.Current.KeyDown(KeyCode, FDownKeyChar, ShiftStateFromMetaState(MetaState));
              FKeyDownHandled := (KeyCode = 0) and (FDownKeyChar = #0);
            end;
            Result := 1;
          end;
        end;
    end;
  end
  else
    FSkipEventQueue.Dequeue;
end;

function TAndroidTextInputManager.ObtainKeyCharacterMap(DeviceId: Integer): JKeyCharacterMap;
begin
  Result := TJKeyCharacterMap.JavaClass.load(DeviceId)
end;

function TAndroidTextInputManager.PlatformKeyToVirtualKey(const PlatformKey: Word; var KeyKind: TKeyKind): Word;
begin
  Result := FKeyMapping.PlatformKeyToVirtualKey(PlatformKey, KeyKind);
end;

function TAndroidTextInputManager.RegisterKeyMapping(const PlatformKey, VirtualKey: Word;
  const KeyKind: TKeyKind): Boolean;
begin
  Result := FKeyMapping.RegisterKeyMapping(PlatformKey, VirtualKey, KeyKind);
end;

procedure TAndroidTextInputManager.SetKeyboardEventToSkip(event: JKeyEvent);
begin
  FSkipEventQueue.Enqueue(event);
end;

function TAndroidTextInputManager.ShiftStateFromMetaState(const AMetaState: Integer): TShiftState;
begin
  Result := [];
  if (AMetaState and AMETA_SHIFT_ON) > 0 then
    Result := Result + [ssShift];
  if (AMetaState and AMETA_ALT_ON) > 0 then
    Result := Result + [ssAlt];
end;

function TAndroidTextInputManager.UnregisterKeyMapping(const PlatformKey: Word): Boolean;
begin
  Result := FKeyMapping.UnregisterKeyMapping(PlatformKey);
end;

function TAndroidTextInputManager.VirtualKeyToPlatformKey(const VirtualKey: Word): Word;
begin
  Result := FKeyMapping.VirtualKeyToPlatformKey(VirtualKey);
end;

{ TPlatformAndroid.TMessageQueueIdleHandler }

constructor TPlatformAndroid.TMessageQueueIdleHandler.Create(APlatform: TPlatformAndroid);
begin
  inherited Create;
  FPlatform := APlatform;
end;

function TPlatformAndroid.TMessageQueueIdleHandler.queueIdle: Boolean;
begin
  Result := True;
  if not FPlatform.Terminating then
    FPlatform.InternalProcessMessages;
end;

end.
