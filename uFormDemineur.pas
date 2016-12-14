unit uFormDemineur;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts, ClassDemineur,
  FMX.StdCtrls, FMX.Controls.Presentation, System.ImageList, FMX.ImgList,
  FMX.Objects, FMX.Styles.Objects, FMX.Ani, FMX.Menus;

type
  TFormDemineur = class(TForm)
    GridLayout: TGridLayout;
    StyleBook: TStyleBook;
    LayoutTop: TLayout;
    TexteMine: TText;
    imgMine: TImage;
    TexteTimer: TText;
    LayoutMain: TLayout;
    RectButton: TRectangle;
    btnEasy: TButton;
    LayoutOptions: TLayout;
    btnHard: TButton;
    btnMiddle: TButton;
    TextePlay: TText;
    faLayoutOptions: TFloatAnimation;
    MainMenu: TMainMenu;
    miNewGame: TMenuItem;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormShow(Sender: TObject);
    procedure btnEasyClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure miNewGameClick(Sender: TObject);
  private
    FDemineur : TDemineur;

    procedure GetActionGame(GameAction : TGameAction);
    procedure GetMine(iMine : integer);
    procedure GetTimer(iSecond : integer);
  public
    { Déclarations publiques }
  end;

var
  FormDemineur: TFormDemineur;

implementation

uses
   System.DateUtils;

{$R *.fmx}

procedure TFormDemineur.btnEasyClick(Sender: TObject);
begin
   if Sender = btnMiddle then
      FDemineur.Level := lvMiddle
   else
   begin
      if Sender = btnHard then
         FDemineur.Level := lvHard
      else
         FDemineur.Level := lvEasy;
   end;

   RectButton.Visible := False;
   FDemineur.Play;
end;

procedure TFormDemineur.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
   if CanClose then
      FreeAndNil(FDemineur);
end;

procedure TFormDemineur.FormCreate(Sender: TObject);
begin
   RectButton.Visible := True;
end;

procedure TFormDemineur.FormShow(Sender: TObject);
begin
   FDemineur              := TDemineur.Create(Self, GridLayout);

   FDemineur.OnGameAction := GetActionGame;
   FDemineur.OnGetMine    := GetMine;
   FDemineur.OnGetTimer   := GetTimer;
end;

procedure TFormDemineur.GetActionGame(GameAction : TGameAction);
begin
   // permet de savoir quand le jeu est gagné, ou perdu
   if GameAction = gaLose then
      TextePlay.Text := 'Perdu !'
   else
      if GameAction = gaWin then
         TextePlay.Text := 'Gagné !'
      else
         TextePlay.Text := 'Commencer';

   faLayoutOptions.StartValue := Self.Height + 1;
   RectButton.Visible         := True;
   faLayoutOptions.Start;
end;

procedure TFormDemineur.GetMine(iMine : integer);
begin
   // ajout d'un effet lors de l'affichage du nombre de mines restantes
   TAnimator.AnimateFloat(TexteMine, 'Font.Size', 35);
   TAnimator.AnimateFloat(TexteMine, 'Font.Size', 25);
   TexteMine.Text := iMine.ToString;
end;

procedure TFormDemineur.GetTimer(iSecond : integer);
begin
   // affichage du chronomètre
   TexteTimer.Text := iSecond.ToString;
end;

procedure TFormDemineur.miNewGameClick(Sender: TObject);
begin
   FDemineur.Stop(gaNewParty);
end;

end.
