program anative;

uses
  Androidapi.Helpers,
  Androidapi.JNI.Os,
  Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.Webkit,
  Androidapi.JNI.Net,
  Androidapi.JNIBridge,
  Androidapi.JNI.App,
  Androidapi.JNI.Support,
  Androidapi.JNI.Provider,
  Androidapi.JNI.Widget,
  Androidapi.JNI.Embarcadero,
  System.Messaging,
  FMX.Dialogs,
  FMX.Platform,
  FMX.Platform.Android,
  FMX.Platform.UI.Android;

{$R *.res}

type
//  TView_OnClickListener = class(TJView_OnClickListener);
//  end;

//  TClickListener = class(TJView_OnClickListener)
////    procedure onClick(v: JView); cdecl;
//  end;

  TCopyButtonClickListener = class(TJavaLocal, JView_OnClickListener)
  public
    procedure onClick(P1: JView); cdecl;
  end;

  TApp = class
  private
    FFormLayout: JViewGroup;
    FView: JFormView;
    FormViewParams: JRelativeLayout_LayoutParams;
    FormLayoutParams: JRelativeLayout_LayoutParams;
    FCopyClickListener: TCopyButtonClickListener;
    procedure ResultCallback(const Sender: TObject; const M: TMessage);
    function ApplicationEventHandler(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    procedure OnCreate;
  public
    constructor Create;
    destructor Destroy; override;
  end;

//procedure TClickListener.onClick(v: JView);
//begin
//
//end;

procedure TCopyButtonClickListener.onClick(P1: JView);
//var
//  TextService: TTextServiceAndroid;
begin
//  TextService := TWindowManager.Current.TextGetService;
//  if TextService <> nil then
//    TextService.CopySelectedText;
//  TWindowManager.Current.TextResetSelection;
//  TWindowManager.Current.HideContextMenu;
  ShowMessage('1212121212');
end;

constructor TApp.Create;
begin
  TMessageManager.DefaultManager.SubscribeToMessage(TMessageResultNotification,ResultCallback);
end;

destructor TApp.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TMessageResultNotification,ResultCallback);
end;

procedure TApp.OnCreate;
var B: JButton;
begin

  FView := TJFormView.JavaClass.init(TAndroidHelper.Context);

//  FView.setListener(FListener);
//  FView.getHolder.addCallback(FSurfaceListener);
  FView.setFocusable(True);
  FView.setFocusableInTouchMode(True);

  FFormLayout := TJRelativeLayout.JavaClass.init(TAndroidHelper.Activity);

  FormViewParams := TJRelativeLayout_LayoutParams.JavaClass.init(TJViewGroup_LayoutParams.JavaClass.MATCH_PARENT,
                                                                 TJViewGroup_LayoutParams.JavaClass.MATCH_PARENT);

  FFormLayout.addView(FView, FormViewParams);

  FormLayoutParams := TJRelativeLayout_LayoutParams.JavaClass.init(TJViewGroup_LayoutParams.JavaClass.MATCH_PARENT,
                                                                   TJViewGroup_LayoutParams.JavaClass.MATCH_PARENT);

  MainActivity.getViewGroup.addView(FFormLayout, FormLayoutParams);

  FFormLayout.setVisibility(TJView.JavaClass.GONE);

//  OnClickListener:=TJView_OnClickListener.Create;
//  OnClickListener.

//  ClickListener:=TClickListener.Create;


  FCopyClickListener := TCopyButtonClickListener.Create;

  B:=TJButton.JavaClass.init(TAndroidHelper.Context);
  B.setText(StrToJCharSequence('1234567890'));
  B.setOnClickListener(FCopyClickListener);
  B.setLayoutParams(TJRelativeLayout_LayoutParams.JavaClass.init(TJViewGroup_LayoutParams.JavaClass.WRAP_CONTENT,
                                                                   TJViewGroup_LayoutParams.JavaClass.WRAP_CONTENT));
  B.setLeft(50);
  B.setTop(100);

  MainActivity.getViewGroup.addView(B);

//  FFormLayout.addView(B);

end;

function TApp.ApplicationEventHandler(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
begin
  Result:=True;
  case AAppEvent of
  TApplicationEvent.FinishedLaunching: OnCreate;
  TApplicationEvent.WillTerminate:;
  end;
end;

procedure TApp.ResultCallback(const Sender: TObject; const M: TMessage);
begin
end;

var App: TApp;
begin

  App:=TApp.Create;

  PlatformAndroid.SetApplicationEventHandler(App.ApplicationEventHandler);

  PlatformAndroid.Run;

end.
