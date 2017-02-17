unit ScoreKeeper;

interface

uses
  Math, SysUtils, Classes;

type
  TScoreKeeper = class
  private
    _PlayerScore1 : Integer;
    _PlayerScore2 : Integer;
    _HighScore : Integer;
    _OnUpdateScores : TNotifyEvent;
    _OnUpdateLives : TNotifyEvent;
    _UpLives : Integer;
    procedure SetPlayerScore1(const Value: Integer);
    procedure SetPlayerScore2(const Value: Integer);
  public
    constructor Create;
    procedure Clear;
    procedure ClearAll;
    property PlayerScore1 : Integer read _PlayerScore1 write SetPlayerScore1;
    property PlayerScore2 : Integer read _PlayerScore2 write SetPlayerScore2;
    property HighScore : Integer read _HighScore;
    property OnUpdateScores : TNotifyEvent read _OnUpdateScores write _OnUpdateScores;
    property OnUpdateLives : TNotifyEvent read _OnUpdateLives write _OnUpdateLives;

    function FormatScore(Value : Integer; MinWidth : Integer = 4): String;
  end;

implementation

uses Settings;

{ TScoreKeeper }

procedure TScoreKeeper.Clear;
begin
  _PlayerScore1 := 0;
  _PlayerScore2 := 0;

  if Assigned(_OnUpdateScores) then _OnUpdateScores(Self);  
end;

procedure TScoreKeeper.ClearAll;
begin
  _PlayerScore1 := 0;
  _PlayerScore2 := 0;
  _HighScore := 0;

  if Assigned(_OnUpdateScores) then _OnUpdateScores(Self);  
end;

constructor TScoreKeeper.Create;
begin
  _PlayerScore1 := 0;
  _PlayerScore2 := 0;
  _HighScore := 0;
  _UpLives:=0;
end;

function TScoreKeeper.FormatScore(Value, MinWidth: Integer): String;
begin
  result := IntToStr(Value);
  if MinWidth>=4 then begin
    if length(result)<MinWidth then begin
      result := StringOfChar('0', MinWidth-length(result)) + result;
    end;
  end;
end;

procedure TScoreKeeper.SetPlayerScore1(const Value: Integer);
begin
  if Value>=0 then begin
    _PlayerScore1 := Value;
    _HighScore := Max(_HighScore, _PlayerScore1);

    if Assigned(_OnUpdateScores) then _OnUpdateScores(Self);

    if (Value div GameSettings.ScoreMarkForNewLife) > _UpLives then begin
      if Assigned(_OnUpdateLives) then _OnUpdateLives(Self);
      _UpLives :=Value div GameSettings.ScoreMarkForNewLife;
    end;
  end;
end;

procedure TScoreKeeper.SetPlayerScore2(const Value: Integer);
begin
  if Value>=0 then begin
    _PlayerScore2 := Value;
    _HighScore := Max(_HighScore, _PlayerScore2);

    if Assigned(_OnUpdateScores) then _OnUpdateScores(Self);

    if (Value div GameSettings.ScoreMarkForNewLife) > _UpLives then begin
      if Assigned(_OnUpdateLives) then _OnUpdateLives(Self);
      _UpLives :=Value div GameSettings.ScoreMarkForNewLife;
    end;        
  end;
end;

end.
