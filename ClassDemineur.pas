// *****************************************************************************
// Démineur avec Firemonkey / Minesweeper with Firemonkey
// Robin VALTOT
// 10/12/2016
// Contact > r.valtot@gmail.com
// Website > http://r.valtot.free.fr
// *****************************************************************************

unit ClassDemineur;

interface

uses
   FMX.Layouts, FMX.StdCtrls, System.Generics.Collections, FMX.Forms, FMX.ImgList,
   System.UITypes, System.Classes, FMX.Types, FMX.Objects, FMX.Styles.Objects;

type
   TGameAction    = (gaWin, gaLose, gaNewParty);
   TLevel         = (lvEasy, lvMiddle, lvHard);

   TOnGetValue    = procedure (iValue     : integer)     of object;
   TOnGameAction  = procedure (GameAction : TGameAction) of object;

   TMineButton = class(TButton)
   strict private
      FbMine      : boolean;
      FbFlag      : boolean;
      FiNombre    : integer;
      FiCol       : integer;
      FiRow       : integer;

      /// <summary>affiche le drapeau sur le bouton</summary>
      procedure SetFlag(const Value : boolean);
   public
      /// <summary>animation lors du clic</summary>
      procedure Animate;

      property bMine      : boolean         read FbMine      write FbMine;
      property bFlag      : boolean         read FbFlag      write SetFlag;
      property iNombre    : integer         read FiNombre    write FiNombre;
      property iCol       : integer         read FiCol       write FiCol;
      property iRow       : integer         read FiRow       write FiRow;
   end;

   TDemineur = class
   const
      CST_WIDTH_BUTTON = 35;
   strict private
      FGridLayout     : TGridLayout;
      FLevel          : TLevel;
      FListMineButton : TObjectList<TMineButton>;
      FiWidth         : integer;
      FiHeight        : integer;
      FiMines         : integer;
      FOwner          : TForm;
      FListColors     : TList<Cardinal>;
      FTimer          : TTimer;
      FiTimerExec     : integer;
      FbLongTap       : boolean;
      FOnGameAction   : TOnGameAction;
      FOnGetMine      : TOnGetValue;
      FOnGetTimer     : TOnGetValue;

      /// <summary>permet de créer les boutons</summary>
      procedure CreateButtons;
      /// <summary>redimensionne la fenêtre principale en fonction du mode de jeu</summary>
      procedure AdjustFormSize;
      /// <summary>quand on relâche un bouton</summary>
      procedure OnMineButtonMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
      /// <summary>lors du clic sur un bouton vide, il faut afficher les boutons adjacents</summary>
      procedure OnEmptyButtonClick(mbEmpty : TMineButton);
      /// <summary>le clic gauche permet de dévoiler le bouton (chiffre ou mine)</summary>
      procedure OnLeftMouseButtonClick(Sender : TObject; bAnimate : boolean = True);
      /// <summary>le clic droit permet d'ajouter un drapeau</summary>
      procedure OnRightMouseButtonClick(Sender : TObject);
      /// <summary>chronomètre lancé toutes les secondes</summary>
      procedure OnTimer(Sender : TObject);
      /// <summary>pour ajouter des drapeaux pas clique long sur mobile</summary>
      procedure OnMineButtonGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
      /// <summary>chargement des couleurs disponible pour les chiffres</summary>
      procedure LoadListColors;
      /// <summary>place des mines aléatoirement</summary>
      procedure AddMines;

      /// <summary>permet de connaitre le nombre de drapeaux posé sur le jeu</summary>
      function GetNumberFlags : integer;
      /// <summary>récupération des index des boutons adjacents d'après bouton précis</summary>
      function GetButtonsAroundMyCurrentButton(iCurrentButton : integer; bOnlyEnabled : boolean = False): TList<integer>;
      /// <summary>permet de savoir si la partie est gagnée</summary>
      function IsWinner : boolean;
   public
      constructor Create(AOwner : TForm; GridLayout : TGridLayout);
      destructor Destroy; override;

      procedure Play;
      procedure Stop(GameAction : TGameAction);

      property Level          : TLevel         read FLevel          write FLevel;
      property OnGameAction   : TOnGameAction  read FOnGameAction   write FOnGameAction;
      property OnGetMine      : TOnGetValue    read FOnGetMine      write FOnGetMine;
      property OnGetTimer     : TOnGetValue    read FOnGetTimer     write FOnGetTimer;
      property iMines         : integer        read FiMines;
   end;

implementation

uses
   System.SysUtils, FMX.Dialogs, System.Types, FMX.Ani;

{ TMineButton }

procedure TMineButton.Animate;
begin
   TAnimator.AnimateFloat(Self, 'Font.Size', 25);
   TAnimator.AnimateFloat(Self, 'Font.Size', 15);

   TAnimator.AnimateFloat(Self, 'Margins.Top',    -10);
   TAnimator.AnimateFloat(Self, 'Margins.Bottom', -10);
   TAnimator.AnimateFloat(Self, 'Margins.Left',   -10);
   TAnimator.AnimateFloat(Self, 'Margins.Right',  -10);

   TAnimator.AnimateFloat(Self, 'Margins.Top',    0);
   TAnimator.AnimateFloat(Self, 'Margins.Bottom', 0);
   TAnimator.AnimateFloat(Self, 'Margins.Left',   0);
   TAnimator.AnimateFloat(Self, 'Margins.Right',  0);
end;

procedure TMineButton.SetFlag(const Value : boolean);
begin
   if FbFlag <> Value then
   begin
      {$IF Defined(ANDROID) or Defined(IOS)}
         if Value then
            Self.Text := 'F'
         else
            Self.StyleLookup := '';
      {$ELSE}
         if Value then
            Self.StyleLookup := 'StyleFlagButton'
         else
            Self.StyleLookup := '';
      {$ENDIF}

      FbFlag := Value;
   end;
end;

{ TDemineur }

function TDemineur.IsWinner : boolean;
var
   iCount, iDisabled : integer;
begin
   iDisabled := 0;

   // récupération des boutons disabled, donc découvert
   for iCount := 0 to FListMineButton.Count - 1 do
   begin
      if not FListMineButton[iCount].Enabled then
         Inc(iDisabled);
   end;

   // si le nombre de bouton découvert + les mines = le nombre total alors on a gagné
   Result := (iDisabled + FiMines) = FListMineButton.Count;
end;

function TDemineur.GetNumberFlags : integer;
var
   i : integer;
begin
   Result := 0;

   for i := 0 to FListMineButton.Count - 1 do
   begin
      if FListMineButton[i].bFlag then
         Inc(Result);
   end;
end;

procedure TDemineur.OnTimer(Sender : TObject);
begin
   Inc(FiTimerExec);

   if Assigned(FOnGetTimer) then
      FOnGetTimer(FiTimerExec);
end;

function TDemineur.GetButtonsAroundMyCurrentButton(iCurrentButton : integer; bOnlyEnabled : boolean = False): TList<integer>;
var
   ListIndex : TList<integer>;
   i        : integer;
begin
   ListIndex := TList<integer>.Create;

   // récupération des positions possible tout autour de notre mine
   ListIndex.Add(iCurrentButton - 1);           // gauche
   ListIndex.Add(iCurrentButton + 1);           // droit
   ListIndex.Add(iCurrentButton - FiWidth);     // haut
   ListIndex.Add(iCurrentButton - FiWidth + 1); // haut-droit
   ListIndex.Add(iCurrentButton - FiWidth - 1); // haut-gauche
   ListIndex.Add(iCurrentButton + FiWidth);     // bas
   ListIndex.Add(iCurrentButton + FiWidth + 1); // bas-droit
   ListIndex.Add(iCurrentButton + FiWidth - 1); // bas-gauche

   for i := ListIndex.Count - 1 downto 0 do
   begin
      // la valeur doit correspondre à l'index d'un bouton, il ne faut pas qu'il soit en dehors de la liste
      // il est possible de prendre que les boutons "Enabled=True"
      // et la différence entre les colonnes doit etre de 0 ou 1
      // car si je prends un bouton en colonne 0 (tout à gauche) cela va me renvoyer le bouton
      // précédent qui lui est tout à droite ..
      if not ((ListIndex[i] <= FListMineButton.Count - 1) and (ListIndex[i] >= 0) and Assigned(FListMineButton[ListIndex[i]]) and (FListMineButton[ListIndex[i]] <> nil) and
              ((not bOnlyEnabled) or (bOnlyEnabled and FListMineButton[ListIndex[i]].Enabled)) and
              ((FListMineButton[ListIndex[i]].iCol - FListMineButton[iCurrentButton].iCol = 0) or (Abs(FListMineButton[ListIndex[i]].iCol - FListMineButton[iCurrentButton].iCol) = 1))
             ) then
         ListIndex.Delete(i);
   end;

   Result := ListIndex;
end;

procedure TDemineur.AdjustFormSize;
begin
   FOwner.Visible := False;

   try
      // resize de la fenêtre pour afficher correctement les boutons
      FOwner.ClientWidth  := (FiWidth  * CST_WIDTH_BUTTON);
      FOwner.ClientHeight := (FiHeight * CST_WIDTH_BUTTON) + 40;

      // on remet la fenêtre au milieu de l'écran
      FOwner.Left := (Screen.Width  - FOwner.Width)  div 2;
      FOwner.Top  := (Screen.Height - FOwner.Height) div 2;
   finally
      FOwner.Visible := True;
   end;
end;

constructor TDemineur.Create(AOwner : TForm; GridLayout: TGridLayout);
begin
   // lien vers la form principale, cela nous permettra de la redimensionner
   FOwner                 := AOwner;

   // initialisation de la grille
   FGridLayout            := GridLayout;
   FGridLayout.ItemWidth  := CST_WIDTH_BUTTON;
   FGridLayout.ItemHeight := CST_WIDTH_BUTTON;

   // par défaut le jeu est en mode "facile"
   FLevel          := lvEasy;

   // liste contenant l'ensemble des boutons
   FListMineButton := TObjectList<TMineButton>.Create;

   // chargement des couleurs pour les chiffres sur les boutons
   FListColors     := TList<Cardinal>.Create;
   LoadListColors;

   // création du timer
   FTimer          := TTimer.Create(nil);
   FTimer.Enabled  := False;
   FTimer.Interval := 1000;
   FTimer.OnTimer  := OnTimer;

   FOnGameAction   := nil;
   FOnGetMine      := nil;
   FOnGetTimer     := nil;

   FbLongTap       := False;
end;

procedure TDemineur.LoadListColors;
begin
   // un bouton peux être à côté de 0 à 8 mines
   // le chiffre 0 n'est pas affiché sur les boutons
   // il faut donc 7 couleurs différentes
   FListColors.Add(TAlphaColorRec.Blue);
   FListColors.Add(TAlphaColorRec.Red);
   FListColors.Add(TAlphaColorRec.Green);
   FListColors.Add(TAlphaColorRec.Purple);
   FListColors.Add(TAlphaColorRec.Coral);
   FListColors.Add(TAlphaColorRec.Darkslateblue);
   FListColors.Add(TAlphaColorRec.Chocolate);
end;

procedure TDemineur.CreateButtons;
var
   iHeight  : integer;
   iWidth   : integer;
   mbButton : TMineButton;
begin
   FListMineButton.Clear;

   // sur téléphone l'écran est rempli de bouton
   {$IF Defined(ANDROID) or Defined(IOS)}
      FiHeight := Trunc((FOwner.ClientHeight - 40) div CST_WIDTH_BUTTON);
      FiWidth  := Trunc(FOwner.ClientWidth div CST_WIDTH_BUTTON);

      // pour avoir la même marge à gauche et à droite
      FGridLayout.Margins.Left := Trunc((FOwner.ClientWidth - (FiWidth * CST_WIDTH_BUTTON)) div 2);
   {$ENDIF}

   // création des boutons
   for iHeight := 0 to FiHeight - 1 do
   begin
      for iWidth := 0 to FiWidth - 1 do
      begin
         mbButton             := TMineButton.Create(FGridLayout);
         mbButton.Parent      := FGridLayout;
         mbButton.iNombre     := 0;
         mbButton.OnMouseUp   := OnMineButtonMouseUp;
         mbButton.ImageIndex  := -1;
         mbButton.bFlag       := False;
         mbButton.Font.Size   := 15;

         // toujours sur téléphone on remplace le clique droit
         // par un appui prolongé sur le bouton
         {$IF Defined(ANDROID) or Defined(IOS)}
            mbButton.Touch.InteractiveGestures := [TInteractiveGesture.LongTap];
            mbButton.OnGesture := OnMineButtonGesture;
         {$ENDIF}

         mbButton.iCol        := iWidth;
         mbButton.iRow        := iHeight;

         mbButton.StyledSettings          := [TStyledSetting.Family];
         mbButton.TextSettings.Font.Style := mbButton.TextSettings.Font.Style + [TFontStyle.fsBold];

         FGridLayout.AddObject(mbButton);
         FListMineButton.Add(mbButton);
      end;
   end;

   // initialisation des mines
   AddMines;

   {$IF Defined(MSWINDOWS) or Defined(MACOS)}
      // on ajuste la taille de la fenêtre au nombre de boutons
      AdjustFormSize;
   {$ENDIF}

   FTimer.Enabled := True;
end;

destructor TDemineur.Destroy;
begin
   FTimer := nil;
   FreeAndNil(FTimer);
   FreeAndNil(FListColors);
   FreeAndNil(FListMineButton);

   inherited;
end;

procedure TDemineur.Play;
begin
   // parametre des différents niveaux
   case FLevel of
      lvEasy:
      begin
         FiWidth  := 8;
         FiHeight := 10;
         FiMines  := 14;
      end;
      lvMiddle:
      begin
         FiWidth  := 12;
         FiHeight := 16;
         FiMines  := 25;
      end;
      lvHard:
      begin
         FiWidth  := 16;
         FiHeight := 20;
         FiMines  := 45;
      end;
   end;

   // remise à zéro du chrono
   FiTimerExec := 0;

   if Assigned(FOnGetMine)  then FOnGetMine(FiMines);
   if Assigned(FOnGetTimer) then FOnGetTimer(FiTimerExec);

   CreateButtons;
end;

procedure TDemineur.OnRightMouseButtonClick(Sender : TObject);
begin
   TMineButton(Sender).bFlag := not TMineButton(Sender).bFlag;

   if Assigned(FOnGetMine) then
      FOnGetMine(FiMines - GetNumberFlags);
end;

procedure TDemineur.OnLeftMouseButtonClick(Sender : TObject; bAnimate : boolean = True);
var
   curMineButton : TMineButton;
begin
   curMineButton := TMineButton(Sender);

   if not curMineButton.bMine then
   begin
      curMineButton.Enabled := False;
      curMineButton.bFlag   := False;

      // si il vaut 0 on affiche les boutons adjacents
      if curMineButton.iNombre = 0 then
      begin
         OnEmptyButtonClick(curMineButton)
      end
      else
      begin
         curMineButton.TextSettings.FontColor := FListColors[curMineButton.iNombre - 1];
         curMineButton.Text                   := IntToStr(curMineButton.iNombre);
      end;

      // pour gagner en fluidité lors du clique sur une case vide
      if bAnimate then
         curMineButton.Animate;

      if IsWinner then
      begin
         FOnGameAction(gaWin);
         FTimer.Enabled := False;
      end;
   end
   else
   begin
      Stop(gaLose);
   end;
end;

procedure TDemineur.OnMineButtonGesture(Sender: TObject;
  const EventInfo: TGestureEventInfo; var Handled: Boolean);
begin
   if EventInfo.GestureID = igiLongTap then
   begin
      FbLongTap := True;
      OnRightMouseButtonClick(Sender);
   end;
end;

procedure TDemineur.OnMineButtonMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
   if not FbLongTap then
   begin
      if Button = TMouseButton.mbLeft then
         OnLeftMouseButtonClick(Sender)

      else if Button = TMouseButton.mbRight then
         OnRightMouseButtonClick(Sender);
   end;

   FbLongTap := False;
end;

procedure TDemineur.OnEmptyButtonClick(mbEmpty : TMineButton);
var
   i, iIndex : integer;
   ListIndex : TList<integer>;
begin
   // je viens de cliquer sur un bouton vide
   iIndex := FListMineButton.IndexOf(mbEmpty);

   try
      // recuperation des boutons adjacents
      ListIndex := GetButtonsAroundMyCurrentButton(iIndex, True);

      for i := 0 to ListIndex.Count - 1 do
         OnLeftMouseButtonClick(FListMineButton[ListIndex[i]], False);
   finally
      FreeAndNil(ListIndex);
   end;
end;

procedure TDemineur.AddMines;
var
   iRandom   : integer;
   mnButton  : TMineButton;
   ListIndex : TList<integer>;
   iMine     : integer;
   iIndex    : integer;
   bTrouve   : boolean;
begin
   for iMine := 0 to FiMines - 1 do
   begin
      // permet de placer aléatoirement les mines
      bTrouve  := False;

      while not bTrouve do
      begin
         // récupération d'un chiffre sur notre interval de boutons
         iRandom  := Random(FListMineButton.Count);
         // récupération du bouton
         mnButton := FListMineButton[iRandom];

         // si ce n'est pas déjà une mine
         if not mnButton.bMine then
         begin
            // on indique que ce bouton est une mine
            mnButton.bMine := True;

            try
               // on incrémente le nombre des cases adjacentes
               ListIndex := GetButtonsAroundMyCurrentButton(iRandom);

               for iIndex := 0 to ListIndex.Count - 1 do
                  FListMineButton[ListIndex[iIndex]].iNombre := FListMineButton[ListIndex[iIndex]].iNombre + 1;
            finally
               FreeAndNil(ListIndex);
            end;

            bTrouve := True;
         end;
      end;
   end;
end;

procedure TDemineur.Stop(GameAction : TGameAction);
var
   iCount : integer;
begin
   // affichage de toutes les mines de la partie
   for iCount := 0 to FListMineButton.Count - 1 do
      if FListMineButton[iCount].bMine then
      begin
         {$IF Defined(ANDROID) or Defined(IOS)}
            FListMineButton[iCount].Text := 'M';
         {$ELSE}
            FListMineButton[iCount].StyleLookup := 'StyleMineButton';
         {$ENDIF}
         end;

   // arrêt du chronomètre
   FTimer.Enabled  := False;
   FiTimerExec     := 0;

   // notification à la fenêtre comme quoi la partie est perdue
   if Assigned(FOnGameAction) then
      FOnGameAction(GameAction);
end;

end.
