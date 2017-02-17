unit Main;

interface

uses
  SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, ExtCtrls,
  StdCtrls, Math, Types, Messages,
  Engine, Settings, JvGradient, JvComponentBase, AppEvnts, Windows, JvExControls,
  GR32_Image, GR32;

type
  { TfrmMain }

  TfrmMain = class(TForm)
    lblDummy1: TLabel;
    lblDummy3: TLabel;
    lblDummy2: TLabel;
    lblHighScore: TLabel;
    pnlStopped: TPanel;
    Image1: TImage;
    Label1: TLabel;
    ApplicationEvents1: TApplicationEvents;
    pnlLivesBar: TPanel;
    lblPlayerLives: TLabel;
    imgPlayerLive1: TImage;
    imgPlayerLive2: TImage;
    JvGradient1: TJvGradient;
    bvlGround: TPaintBox;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Image2: TImage;
    Image3: TImage;
    Image4: TImage;
    Image5: TImage;
    VpLEDLabel1: TLabel;
    VpLEDLabel2: TLabel;
    imgPlayerLive3: TImage;
    imgPlayerLive4: TImage;
    imgPlayerLive5: TImage;
    pnlGameScreen: TPaintBox32;
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure bvlGroundPaint(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ApplicationEvents1Message(var Msg: tagMSG; var Handled: Boolean);
    procedure ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
  private
    { Private declarations }
    GameEngine : TEngine;
    procedure OnStartGame(Sender: TObject);
    procedure OnPauseGame(Sender: TObject);
    procedure OnStopGame(Sender: TObject);
    procedure OnUpdateScores(Sender: TObject);
    procedure OnUpdateLives(Sender: TObject);
    procedure OnUpdateGroundHole(Sender : TObject);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
begin
  pnlGameScreen.Invalidate;
end;

procedure TfrmMain.ApplicationEvents1Message(var Msg: tagMSG;
  var Handled: Boolean);
begin
  if Msg.hwnd = pnlGameScreen.Handle then begin
    case Msg.message of
      WM_SYSKEYDOWN  :
        if msg.wParam = 115 then begin
          Handled := true;
          Close;
        end else begin
          Handled := true;
        end;
      WM_KEYDOWN, WM_KEYUP: begin
        Handled := true;
        GameEngine.ProcessKeyDown(msg.wParam);
       end;
    end;
  end else begin
    case Msg.message of
      WM_SYSKEYDOWN  :
        if msg.wParam = 115 then begin
          Handled := true;
          Close;
        end else begin
          Handled := true;
        end;
      WM_KEYDOWN, WM_KEYUP: begin
        Handled := true;
        GameEngine.ProcessKeyDown(msg.wParam);
       end;
    end;
  end;
end;

procedure TfrmMain.bvlGroundPaint(Sender: TObject);
var
  i: Integer;
begin
  bvlGround.Canvas.Pen.Color := clWhite;
  bvlGround.Canvas.MoveTo(0,1);
  bvlGround.Canvas.LineTo(bvlGround.Width, 1);
  bvlGround.Canvas.MoveTo(0,2);
  bvlGround.Canvas.LineTo(bvlGround.Width, 2);

  for i := 0 to Length(GameEngine.GroundHoles) - 1 do begin
    if GameEngine.GroundHoles[i] then begin
      bvlGround.Canvas.Pen.Color := clBlack;
      bvlGround.Canvas.Brush.Color := clBlack;      
      bvlGround.Canvas.FillRect(Rect(i-bvlGround.Left , 1, i+3-bvlGround.Left, 3));
    end;
  end;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  GameEngine.Free;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  // Set cursors
  Cursor := crNone;
  pnlGameScreen.Cursor := crNone;
  pnlStopped.Cursor := crNone;

  pnlGameScreen.Buffer.Clear;

  FormResize(Sender);

  GameEngine := TEngine.Create(pnlGameScreen.Buffer);
  GameEngine.OnStartGame := OnStartGame;
  GameEngine.OnPauseGame := OnPauseGame;
  GameEngine.OnStopGame  := OnStopGame;

  GameEngine.OnUpdateLives := OnUpdateLives;
  GameEngine.OnUpdateGroundHole := OnUpdateGroundHole;
  GameEngine.ScoreKeeper.OnUpdateScores := OnUpdateScores;
end;

procedure TfrmMain.FormResize(Sender: TObject);
begin
  GameSettings.WindowHeight := pnlGameScreen.Height;
  GameSettings.WindowWidth := pnlGameScreen.Width;

  pnlGameScreen.Buffer.SetSize(pnlGameScreen.Width, pnlGameScreen.Height);
end;

procedure TfrmMain.OnPauseGame(Sender: TObject);
begin
  pnlStopped.Visible := false;
  pnlGameScreen.Visible := true;
  pnlLivesBar.Visible := true;
end;

procedure TfrmMain.OnStartGame;
begin
  pnlStopped.Visible := false;
  pnlGameScreen.Visible := true;
  pnlLivesBar.Visible := true;
end;

procedure TfrmMain.OnStopGame(Sender: TObject);
begin
  pnlGameScreen.Visible := false;
  pnlStopped.Visible := true;
  pnlLivesBar.Visible := false;  
end;

procedure TfrmMain.OnUpdateGroundHole(Sender : TObject);
begin
  bvlGround.Invalidate;
end;

procedure TfrmMain.OnUpdateLives;
begin
  lblPlayerLives.Caption := IntToStr(GameEngine.PlayerLives);
  imgPlayerLive1.Visible := GameEngine.PlayerLives > 1;
  imgPlayerLive2.Visible := GameEngine.PlayerLives > 2;
  imgPlayerLive3.Visible := GameEngine.PlayerLives > 3;
  imgPlayerLive4.Visible := GameEngine.PlayerLives > 4;
  imgPlayerLive5.Visible := GameEngine.PlayerLives > 5;
end;

procedure TfrmMain.OnUpdateScores;
begin
  VpLEDLabel1.Caption := GameEngine.ScoreKeeper.FormatScore(GameEngine.ScoreKeeper.PlayerScore1);
  VpLEDLabel2.Caption := GameEngine.ScoreKeeper.FormatScore(GameEngine.ScoreKeeper.PlayerScore2);
  lblHighScore.Caption := GameEngine.ScoreKeeper.FormatScore(GameEngine.ScoreKeeper.HighScore);
end;

end.
