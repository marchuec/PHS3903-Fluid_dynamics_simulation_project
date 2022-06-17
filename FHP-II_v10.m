% IMPLÉMENTATION FHP-II 
% v10

%Ajouts v03
% - Ajouts de HPP v08 (QM, enregistrement vidéo fonctionnel, redéfinition des moyennes
%(vitesse,densité) et 3e figure où la vitesse moyenne est soustraite)
% - Validation du code de Yasmine
% - Changer la dimension de l'obstacle
% - Modifier l'expression de la viscosité

%Ajouts v04
% - Correction des conditions frontières (lignes paires/impaires)
% - Équation viscosité des différents FHP
% - Vitesse du son
% - Toutes les collisions de FHP-II (+12 collisions (1 repos + 1 -> 2) et
% (2 -> 1 repos +1)

%Ajouts v05
% - Calcul vitesse du son à partir d'un grpahique
% - Enlever les calculs et collision de FHP-III

%Ajouts v06:
% - Enregistrement vidéo (2 figures)
% - Amélioration de la présentation des résultats
% - Enregistrement du nb. de particules et QM dans .txt
% - Correction propagation 'Conditions frontières' (gauche/haut, gauche/bas,
% droite/haut, droite/bas)
% - Prise en charge des collisions aux noeuds des parois (on lit gauche_4 au lieu de gauche_4c car une collision change le système)

%Ajouts v07:
% - Positionnement des obstacles

%Ajouts v08;
% - Partie enregistrement des données
% - Enregistrement .fig (3 figures)
% - Enregistrement .csv (nb. particules, QM, Re)
% - Enregistrement .csv (vitesses moyennes x et y)
% - Pas de collisions entre particules pour les noeuds des parois du haut et du bas
% - Plot de la vorticité

%Ajouts v09:
% - Exportation du workspace au complet uniquement
% - Correction nombre de Reynold

clc; clear all;

t_max=100000;              %Nb. d'itérations
taille_grille_x=400;       %Taille de la grille (doit être multiple de taille_moy)
taille_grille_y=250;        %Doit être multiple de 6 à cause de l'obstacle aussi...
taille_moy_x=10;            %Taille du moyennage
taille_moy_y=10;                            
temps_pause=0;              %Temps d'attente avant update figure [s]
maj_macro=50;               %Mise à jour propriété macroscopiques
maj_vid= 100;                 %Mise à jour vidéo
maj_img= 100;                 %Mise à jour images .fig
maj_fich=100;                %Mise à jour fichiers
forme='pas obstacle';           %Forme de l'obstacle (cylindre, pas d'obstacle, plaque)            
emplacement='/Users/marc-antoinehuet/Desktop/Résultats finaux/FHP-sim4/';
nom_video1=[emplacement 'fig1'];
nom_video3=[emplacement 'fig3'];
nom_img1=nom_video1;
nom_img3=nom_video3;

%Probabilité initiale à changer
prob_occ = [35 25 20 15 20 25 10];

%Bouton d'arrêt
handlepushbutton = uicontrol('Style', 'PushButton', 'String', 'Arrêt boucle', ...
                        'Callback', 'delete(gcbf)');
arret=0;

%Enregistrement de la vidéo et du fichier .txt
res1=[0 0 1000 750];       %'Résolution' des vidéo
res3=[0 0 1000 1500];
res_on='off';

video1=VideoWriter(nom_video1,'MPEG-4');
video3=VideoWriter(nom_video3,'MPEG-4');
video1.FrameRate=10;
video3.FrameRate=10;

open(video1); open(video3); 


%Il existe 3 types de noeuds : frontières (paroi du haut, du bas, entrée,
%sortie du flux), intérieur du domaine et obstacle. Une matrice contient
%l'information sur obstacle/pas obstacle, 1=obstacle, 0=pas obstacle.


%-------------------- INITIALISATION DE LA GRILLE -------------------------

numx=taille_grille_x;         %Nombre de noeuds en x et en y
numy=taille_grille_y;

%              3   2
%               \ /
%            4 - O - 1
%               / \
%              5   6

droite_1=zeros(numy,numx);
haut_2=zeros(numy,numx);
haut_3=zeros(numy,numx);   
gauche_4=zeros(numy,numx); 
bas_5=zeros(numy,numx);  
bas_6=zeros(numy,numx);
repos=zeros(numy,numx);

%------------------------ DÉFINITION OBSTACLE -----------------------------

[columnsInImage, rowsInImage] = meshgrid(1:numx, 1:numy);

centre_y = round(numy/2);

%Forme de l'obstacle
if strcmp(forme,'cylindre')
    centre_x = round(numx*0.25);
    rayon = 5;
    obs = double((rowsInImage - centre_y).^2 + (columnsInImage - centre_x).^2 <= rayon.^2);
    dimension_obs=2*rayon;

elseif strcmp(forme,'plaque')
    centre_x = round(numx*0.2);
    width=1;
    height=50;
    dimension_obs=height;
    
    width_vect=round([centre_x-width/2:centre_x+width/2]);
    height_vect=round([centre_y-height/2:centre_y+height/2]);
    
    obs=(ismember(columnsInImage,width_vect) & ismember(rowsInImage,height_vect));
   
elseif strcmp(forme, 'pas obstacle');
    obs=zeros(numy,numx);
    dimension_obs=0;
end

%Parois
parois=zeros(taille_grille_y,taille_grille_x);
parois([1 numy],:)=1;

%----------------------- DISTRIBUTION INITIALE ----------------------------

for k=1:7
    pos_occ=find(randi(100,numy,numx)<=prob_occ(k) & ~obs & ~parois);
    if k==1
    	droite_1(pos_occ)=1;
    elseif k==2
        haut_2(pos_occ)=1;
    elseif k==3 
    	haut_3(pos_occ)=1;
    elseif k==4
    	gauche_4(pos_occ)=1;
    elseif k==5
    	bas_5(pos_occ)=1;
    elseif k==6
    	bas_6(pos_occ)=1;
    elseif k==7
    	repos(pos_occ)=1;
    end
end

%On élimine les particules vers le bas (paroi du haut) et vers le haut
%(paroi du bas)
haut_3(numy,:)=0;
haut_2(numy,:)=0;
bas_5(1,:)=0;
bas_6(1,:)=0;

%Nombre de particules initial
%nb_particules(1)= sum(sum(droite_1 + haut_2 + haut_3 + gauche_4 + bas_5 + bas_6 + repos));
%fprintf('nb de particules = %d\n', nb_particules(1));

%--------------------MISE À JOUR DE L'ÉTAT DU SYSTÈME----------------------
temps_tot=0;
tic

[gridx,gridy]=meshgrid(1:numx,1:numy);
for t=1:t_max  

   %%%%%------------------- PHASE 1 : COLLISIONS -------------------%%%%%%
%     %Copies des matrices de direction
    haut_3c=haut_3;  
    haut_2c=haut_2;  
    gauche_4c=gauche_4;  
    droite_1c=droite_1;
    bas_5c=bas_5;  
    bas_6c=bas_6;
    repos_c=repos;
% 
%     %-----TOUS LES NOEUDS-----%

%Collision frontale à deux particules (avec/sans repos) 
        %Cas 1
    prob_col=50; %Probabilité 
    pos_col=find(gauche_4c & droite_1c & ~haut_2c & ~haut_3c & ~bas_5c & ~bas_6c & ~obs & ~parois);
    
    gauche_4(pos_col)=0; 
    droite_1(pos_col)=0;

    prob=randi(100,1,length(pos_col)) <= prob_col;
    prob_1= find(prob);
    for i=1:length(prob_1)
        haut_2(pos_col(prob_1(i)))=1;
        bas_5(pos_col(prob_1(i)))=1;
    end
    prob_2=find(~prob);
    for i=1:length(prob_2)
         haut_3(pos_col(prob_2(i)))=1;
         bas_6(pos_col(prob_2(i)))=1;
    end

        %Cas 2
    pos_col=find(haut_2c & bas_5c & ~droite_1c & ~haut_3c & ~gauche_4c & ~bas_6c & ~obs & ~parois);
    
    haut_2(pos_col)=0; 
    bas_5(pos_col)=0;

    prob=randi(100,1,length(pos_col)) < prob_col;
    prob_1= find(prob);
    for i=1:length(prob_1)
        droite_1(pos_col(prob_1(i)))=1;
        gauche_4(pos_col(prob_1(i)))=1;
    end
    prob_2=find(~prob);
    for i=1:length(prob_2)
         haut_3(pos_col(prob_2(i)))=1;
         bas_6(pos_col(prob_2(i)))=1;
    end

        %Cas 3
    pos_col=find(haut_2c & gauche_4c & bas_6c & ~haut_3c & ~droite_1c & ~bas_5c & ~obs & ~parois);
    
    haut_3(pos_col)=0; 
    bas_6(pos_col)=0;
    
    prob=randi(100,1,length(pos_col)) < prob_col;
    prob_1= find(prob);
    for i=1:length(prob_1)
        droite_1(pos_col(prob_1(i)))=1;
        gauche_4(pos_col(prob_1(i)))=1;
    end
    prob_2=find(~prob);
    for i=1:length(prob_2)
         haut_2(pos_col(prob_2(i)))=1;
         bas_5(pos_col(prob_2(i)))=1;
    end


%Collision symétrique à 3 particules (avec/sans repos)
        %Cas 1
    pos_col=find(haut_2c & gauche_4c & bas_6c & ~haut_3c & ~droite_1c & ~bas_5c & ~obs & ~parois);
    
    haut_2(pos_col)=0; 
    gauche_4(pos_col)=0;
    bas_6(pos_col)=0;
    
    droite_1(pos_col)=1;
    haut_3(pos_col)=1;
    bas_5(pos_col)=1;
    
        %Cas 2
    pos_col=find(droite_1c & haut_3c & bas_5c & ~haut_2c & ~gauche_4c & ~bas_6c & ~obs & ~parois);
    
    droite_1(pos_col)=0; 
    haut_3(pos_col)=0;
    bas_5(pos_col)=0;
    
    haut_2(pos_col)=1;
    gauche_4(pos_col)=1;
    bas_6(pos_col)=1;

%Collision à 2 particule (1 repos + 1 -> 2)
         %Cas 1
    pos_col=find(repos_c & droite_1c & ~haut_2c & ~haut_3c & ~gauche_4c & ~bas_5c & ~bas_6c & ~obs & ~parois);
    
    repos(pos_col)=0;
    droite_1(pos_col)=0;
    
    haut_2(pos_col)=1; 
    bas_6(pos_col)=1;
             
        %Cas 2
    pos_col=find(repos_c & haut_2c & ~droite_1c & ~haut_3c & ~gauche_4c & ~bas_5c & ~bas_6c & ~obs & ~parois);
    
    repos(pos_col)=0;
    haut_2(pos_col)=0;
    
    droite_1(pos_col)=1; 
    haut_3(pos_col)=1;    
    
    	%Cas 3
    pos_col=find(repos_c & haut_3c & ~haut_2c & ~droite_1c & ~gauche_4c & ~bas_5c & ~bas_6c & ~obs & ~parois);
    
    repos(pos_col)=0;
    haut_3(pos_col)=0;
    
    haut_2(pos_col)=1; 
    gauche_4(pos_col)=1;
    
    	%Cas 4
    pos_col=find(repos_c & gauche_4c & ~haut_2c & ~haut_3c & ~droite_1c & ~bas_5c & ~bas_6c & ~obs & ~parois);
    
    repos(pos_col)=0;
    gauche_4(pos_col)=0;
    
    haut_3(pos_col)=1; 
    bas_5(pos_col)=1;
    
    	%Cas 5
    pos_col=find(repos_c & bas_5c & ~haut_2c & ~haut_3c & ~gauche_4c & ~droite_1c & ~bas_6c & ~obs & ~parois);
    
    repos(pos_col)=0;
    bas_5(pos_col)=0;
    
    gauche_4(pos_col)=1; 
    bas_6(pos_col)=1;
    
    	%Cas 6
    pos_col=find(repos_c & bas_6c & ~haut_2c & ~haut_3c & ~gauche_4c & ~bas_5c & ~droite_1c & ~obs & ~parois);
    
    repos(pos_col)=0;
    bas_6(pos_col)=0;
    
    droite_1(pos_col)=1; 
    bas_5(pos_col)=1;
    
%Collision à 2 particule (2 -> 1 repos + 1)    
        %Cas 1
    pos_col=find(haut_2c & bas_6c & ~droite_1c & ~haut_3c & ~gauche_4c & ~bas_5c & ~repos_c & ~obs & ~parois);
    
    haut_2(pos_col)=0; 
    bas_6(pos_col)=0;
    
    repos(pos_col)=1;
    droite_1(pos_col)=1;
 
        %Cas 2
    pos_col=find(droite_1c & haut_3c & ~haut_2c & ~bas_6c & ~gauche_4c & ~bas_5c & ~repos_c & ~obs & ~parois);
    
    droite_1(pos_col)=0; 
    haut_3(pos_col)=0;
    
    repos(pos_col)=1;
    haut_2(pos_col)=1; 
    
        %Cas 3
    pos_col=find(haut_2c & gauche_4c & ~droite_1c & ~haut_3c & ~bas_6c & ~bas_5c & ~repos_c & ~obs & ~parois);
    
    haut_2(pos_col)=0; 
    gauche_4(pos_col)=0;
    
    repos(pos_col)=1;
    haut_3(pos_col)=1; 
    
        %Cas 4
    pos_col=find(haut_3c & bas_5c & ~droite_1c & ~haut_2c & ~gauche_4c & ~bas_6c & ~repos_c & ~obs & ~parois);
    
    haut_3(pos_col)=0; 
    bas_5(pos_col)=0;
    
    repos(pos_col)=1;
    gauche_4(pos_col)=1; 
    
        %Cas 5
    pos_col=find(gauche_4c & bas_6c & ~droite_1c & ~haut_3c & ~haut_2c & ~bas_5c & ~repos_c & ~obs & ~parois);
    
    gauche_4(pos_col)=0; 
    bas_6(pos_col)=0;
    
    repos(pos_col)=1;
    bas_5(pos_col)=1; 
    
        %Cas 6
    pos_col=find(bas_5c & droite_1c & ~bas_6c & ~haut_3c & ~gauche_4c & ~haut_2c & ~repos_c & ~obs & ~parois);
    
    bas_5(pos_col)=0; 
    droite_1(pos_col)=0;
    
    repos(pos_col)=1;
    bas_6(pos_col)=1;
    
   %Collision à trois particules (2 particules avec spectateur) (FHP-II)
         %Cas 1
    pos_col=find(haut_3c & bas_5c & bas_6c & ~droite_1c & ~haut_2c & ~gauche_4c & ~obs & ~repos_c & ~parois);
    
    haut_3(pos_col)=0;
    haut_5(pos_col)=0;
    bas_6(pos_col)=0;
    
    droite_1(pos_col)=1; 
    gauche_4(pos_col)=1;
    bas_5(pos_col)=1;
    
        %Cas 2
    pos_col=find(droite_1c & gauche_4c & bas_5c & ~haut_2c & ~haut_3c & ~bas_6c & ~obs & ~repos_c & ~parois);
    
    droite_1(pos_col)=0; 
    gauche_4(pos_col)=0;
    bas_5(pos_col)=0;
    
    haut_3(pos_col)=1;
    bas_5(pos_col)=1;
    bas_6(pos_col)=1;
     
    
    %-----RÉFLEXIONS PAROIS DU HAUT ET DU BAS-----%

    %Paroi du haut
    prob=randi(1,100,4);
    i=numy;
    x=find(haut_2c(i,:));
    bas_5(i,x)=1;
    haut_2(i,x)=0; 
    
    x=find(haut_3c(i,:));
    bas_6(i,x)=1;
    haut_3(i,x)=0;
    
    %Paroi du bas
    i=1;
    x=find(bas_5c(i,:));
    bas_5(i,x)=0;
    haut_2(i,x)=1;
    
    x=find(bas_6c(i,:));
    bas_6(i,x)=0;
    haut_3(i,x)=1;

    %-----RÉFLEXIONS OBSTACLE-----%

    [y,x] = find(obs==1);
    
    for i=1:length(x)
        if droite_1c(y(i),x(i))==1            %Rebond vers la gauche
            gauche_4(y(i),x(i))=1; 
            droite_1(y(i),x(i))=0;
        end
        if gauche_4c(y(i),x(i))==1            %Rebond vers la droite
            droite_1(y(i),x(i))=1;
            gauche_4(y(i),x(i))=0;
        end
        if haut_2c(y(i),x(i))==1            %Rebond vers le bas-gauche
            bas_5(y(i),x(i))=1;
            haut_2(y(i),x(i))=0;
        end
        if haut_3c(y(i),x(i))==1            %Rebond vers le bas-droit
            bas_6(y(i),x(i))=1;
            haut_3(y(i),x(i))=0;
        end
        if bas_5c(y(i),x(i))==1            %Rebond vers le haut-droit
            haut_2(y(i),x(i))=1;
            bas_5(y(i),x(i))=0;
        end
        if bas_6c(y(i),x(i))==1            %Rebond vers le haut-gauche
            haut_3(y(i),x(i))=1;
            bas_6(y(i),x(i))=0;
        end
    end

    %%%%%------------------- PHASE 2 : PROPAGATION --------------------%%%%
    %Les particules sont propagées du noeud (i,j) vers les voisins
    
    %Copies des matrices de direction
    haut_3c=haut_3;  
    haut_2c=haut_2;  
    gauche_4c=gauche_4;  
    droite_1c=droite_1;
    bas_5c=bas_5;  
    bas_6c=bas_6;
%     
%     %Réinitialisation
    droite_1=zeros(numy,numx);
     haut_2=zeros(numy,numx);
    haut_3=zeros(numy,numx);   
    gauche_4=zeros(numy,numx); 
     bas_5=zeros(numy,numx);  
     bas_6=zeros(numy,numx);
     
    %-------Propagation vers la droite. Exclusion : frontière droite-------

    [y,x]=find(droite_1c & gridx~=numx);
    for i=1:length(x)
        droite_1(y(i),x(i)+1)=1;
    end

    %-------Propagation vers la gauche. Exclusion : frontière gauche-------

    [y,x]=find(gauche_4c & gridx~=1);
    for i=1:length(x)
        gauche_4(y(i),x(i)-1)=1;
    end
   
    %----------------------Propagation vers le haut/gauche-----------------
    [y,x]=find(haut_3c & gridy~=numy);
    for i=1:length(x)
        if x(i)~=1 && rem(y(i),2) ==0 %Lignes paires
            haut_3(y(i)+1,x(i)-1)=1;
        elseif rem(y(i),2) ==1 %Lignes impaires
            haut_3(y(i)+1,x(i))=1;
        end
    end
    %----------------------Propagation vers le haut/droite-----------------
    
    [y,x]=find(haut_2c & gridy~=numy);
    for i=1:length(x)
        if rem(y(i),2) ==0 %Lignes paires
            haut_2(y(i)+1,x(i))=1;
        elseif x(i)~=numx && rem(y(i),2) ==1 %Lignes impaires
            haut_2(y(i)+1,x(i)+1)=1;
        end
    end
    
    %------------------Propagation vers le bas/gauche----------------------

    [y,x]=find(bas_5c & gridy~=1);
    for i=1:length(x)
        if x(i)~=1 && rem(y(i),2) ==0 %Lignes paires
            bas_5(y(i)-1,x(i)-1)=1;
        elseif rem(y(i),2) ==1 %Lignes impaires
            bas_5(y(i)-1,x(i))=1;
        end
    end
     
    %------------------Propagation vers le bas/droite----------------------
    
    [y,x]=find(bas_6c & gridy~=1);
    for i=1:length(x)
        if rem(y(i),2) ==0 %Lignes paires
            bas_6(y(i)-1,x(i))=1;
        elseif x(i)~=numx && rem(y(i),2) ==1 %Lignes impaires
            bas_6(y(i)-1,x(i)+1)=1;
        end
    end
    
    
    %----------------------Conditions périodiques--------------------------
     
    %Frontière de gauche
    y=find(gauche_4c(:,1));
    gauche_4(y,numx)=1;
    
    %Frontière de gauche/haut
    y=find(haut_3c(:,1) & rem(gridy(:,1),2)==0 & gridy(:,1)~=numy);
    haut_3(y+1,numx)=1;
    
    %Frontière de gauche/bas
    y=find(bas_5c(:,1) & rem(gridy(:,1),2)==0 & gridy(:,1)~=1);
    bas_5(y-1,numx)=1;
    
    %Frontière de droite
    y=find(droite_1c(:,numx));
    droite_1(y,1)=1;

    %Frontière de droite/haut
    y=find(haut_2c(:,numx) & rem(gridy(:,1),2)==1 & gridy(:,1)~=numy);
    haut_2(y+1,1)=1;

    %Frontière de droite/bas
    y=find(bas_6c(:,numx) & rem(gridy(:,1),2)==1 & gridy(:,1)~=1);
    bas_6(y-1,1)=1;

     %%%%------------- PHASE 3 : PROPRIÉTÉS MACROSCOPIQUES ------------%%%%
     if ~rem(t,maj_macro)
         nb_grains_x=numx/taille_moy_x;         %Nombre de noeuds pour moyenner
         nb_grains_y=numy/taille_moy_y;
         nb_noeuds_grain=taille_moy_x*taille_moy_y;
         v_x=zeros(nb_grains_y,nb_grains_x);
         v_y=zeros(nb_grains_y,nb_grains_x);
         
         t_rel=t/maj_macro;

         for i=1:nb_grains_y
             for j=1:nb_grains_x
                 pos_y1=(i-1)*taille_moy_y+1;
                 pos_y2=i*taille_moy_y;
                 pos_x1=(j-1)*taille_moy_x+1;
                 pos_x2=j*taille_moy_x;
                 
                 %Somme des particules dans chaque direction par grain
                 direction_1=sum(sum(droite_1(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_2=sum(sum(haut_2(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_3=sum(sum(haut_3(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_4=sum(sum(gauche_4(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_5=sum(sum(bas_5(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_6=sum(sum(bas_6(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_7=sum(sum(repos(pos_y1:pos_y2, pos_x1:pos_x2)));
                 
                 %Vitesse de chaque grain
                 vx_p=direction_1+ cos(pi/3)*direction_2 + cos(pi/3)*direction_6;
                 vx_n=direction_4+ cos(pi/3)*direction_3 + cos(pi/3)*direction_5;
                 vy_p=sin(pi/3)*direction_2 + sin(pi/3)*direction_3;
                 vy_n=sin(pi/3)*direction_5 + sin(pi/3)*direction_6;
                 
                 v_x(i,j)= vx_p - vx_n;    
                 v_y(i,j)= vy_p - vy_n;
                 
                 v_moy(i,j)=sqrt((v_x(i,j)^2+v_y(i,j)^2))/nb_noeuds_grain;  %Vitesse moyenne par noeud pour 1 grain
                 
                 %Densité moyenne par noeud pour 1 grain (particules/noeud)
                 rho_moy(i,j)=(direction_1+direction_2+direction_3+direction_4+direction_5+direction_6+direction_7)/nb_noeuds_grain;     
             end
         end
         
         %Vitesses moyennes totales
         v_moy_moy=mean(mean(v_moy));   %Vitesse moyenne par noeud totale
         v_moyx=mean(mean(v_x));              %Vitesse moyenne par grain totale (en x)
         v_moyy=mean(mean(v_y));              %Vitesse moyenne par grain totale (en y)
         
         %Nombre de particules
         nb_particules(t_rel)=sum(sum(droite_1 + haut_2 + haut_3 + gauche_4 + bas_5 + bas_6 + repos));;
         %fprintf('nb de particules = %d\n', nb_particules(t_rel));
         
         %Quantité de mouvement totale
         QM_x(t_rel)=sum(sum(v_x));
         QM_y(t_rel)=sum(sum(v_y));
         QM(t_rel)=sqrt(QM_x(t_rel)^2+QM_y(t_rel)^2);
         %fprintf('QM = %.1f\n', QM(t_rel));
         
         %--------Nombre de Reynolds-------
            % Re = VL/nu
            % Vitesse = vitesse moyenne par noeud
            % Dimension = taille_obstacle/numy
            % Viscosité cinématique
            
%         %FHP-I (6bits)
%         rho=mean(mean(rho_moy));                %Densité par noeud 
%         d=rho/6;                                %Densité par cellule
%         cin_viscosity=1/(12*d*(1-d)^3) - 1/8;   %Viscocité cinématique par noeud
%         g=(rho-3)/(rho-6);                      %Facteur g
%         P=(rho/2)*(1-g*v_moy_moy^2);            %Pression du fluide
%         v_son(t_rel)=sqrt(P/rho);               %Vitesse du son en pix/delta(t)
        
        %FHP-II/III (7bits)
        rho=mean(mean(rho_moy));                %Densité par noeud 
        d=rho/7;                                %Densité par cellule
        g=(7/12)*(1-2*d)/(1-d);                 %Facteur g
        P=(3*d)*(1-(5/6)*g*v_moy_moy^2);        %Pression du fluide
        v_son(t_rel)=sqrt(P/rho);               %Vitesse du son théorique en pix/delta(t)
         
        %FHP-II 
        cin_viscosity=1/(28*d*(1-(4*d/7))*(1-d)^3) - 1/8;  %Viscocité cinématique par noeud
        
        %Calcul
        Re(t_rel)=v_moy_moy*dimension_obs/cin_viscosity;
        Re_coeff(t_rel)= v_son(t_rel)*g/cin_viscosity;
        %fprintf('Re = %.1f\n', Re(t_rel));
        %fprintf('vitesse_son = %.1f\n',v_son(t_rel)); 
        
        %Vorticité
        [curlx_back,curly_back]=curl(v_x-v_moyx,v_y-v_moyy);
        [curlx,curly]=curl(v_x,v_y);
        curl_amplitude_back=sqrt(curlx_back.^2+curly_back.^2);
        curl_amplitude=sqrt(curlx.^2+curly.^2);


    %Mise à jour des figures
    %FIGURE 1 - CHAMP DE VITESSE STANDARD
        gcf1=figure(1);
        if strcmp(res_on,'on')
            set(gcf1,'Position', res1)
        end
        %subplot(2,1,1);
        x=1:nb_grains_x;
        y=1:nb_grains_y;
        quiver(x,y,v_x,v_y); hold on; 
        
        temps_ite=toc;
        temps_tot=temps_tot+temps_ite;
        tic
        
        %Formattage des propriétés
        temps_ite=round(temps_ite,1);
        temps_tot=round(temps_tot)/60;
        Re(t_rel)=round(Re(t_rel),0);
        QM(t_rel)=round(QM(t_rel),0);
        
        %Parois et obstacle
        plot([0; nb_grains_x+1], [0; 0], 'r-');                          %paroi du bas
        plot([0; nb_grains_x+1], [nb_grains_y+1; nb_grains_y+1], 'r-');    %paroi du haut
        set(gca,'YTick',[],'XTick',[],'box','off','xcolor','w','ycolor','w')
        hold off
        if strcmp(forme,'cylindre')
            viscircles([centre_x/taille_moy_x centre_y/taille_moy_y],rayon/taille_moy_y);
        elseif strcmp(forme,'plaque');
            rectangle('Position', [(centre_x-width/2)/taille_moy_x, (centre_y-height/2)/taille_moy_y, width/taille_moy_x, height/taille_moy_y]);       %[x(origin) y(origin) width height]
        end
        axis([-1 nb_grains_x+2 -1 nb_grains_y+2]);
        text=['ite = ' num2str(t) ',  t_{ite} = ' num2str(temps_ite) ',  t_{tot} = ' num2str(temps_tot), ',  taille = ' num2str(taille_grille_x) 'x' num2str(taille_grille_y), ' (' num2str(dimension_obs) ')' ',  Distrib. = ' mat2str(prob_occ) ',   Moy = ' num2str(taille_moy_x)   ',   Re = ' num2str(Re(t_rel)) ',    Nb. = ' num2str(nb_particules(t_rel)) ',   QM = ' num2str(QM(t_rel))];
        title(text, 'fontsize', 9);
        %xlabel('Position en x', 'fontsize', 12);
        %ylabel('Position en y', 'fontsize', 12);
        hold off
        
        
    %FIGURE 1 - CHAMP DE VITESSE SANS BACKGROUND (NE PAS MODIFIER!!!!)
%         %gcf2=figure(2)
%         subplot(2,1,2);
%         x=1:nb_grains_x;
%         y=1:nb_grains_y;
%         quiver(x,y,v_x-v_moyx,v_y-v_moyy); hold on;      %Soustraction du background
%         
%         %Parois et obstacle
%         plot([0; nb_grains_x+1], [0; 0], 'r-');       %paroi du bas
%         plot([0; nb_grains_x+1], [nb_grains_y+1; nb_grains_y+1], 'r-');    %paroi du haut
%         set(gca,'YTick',[],'XTick',[],'box','off','xcolor','w','ycolor','w')
%         hold off
%         if strcmp(forme,'cylindre')
%             viscircles([centre_x/taille_moy_x centre_y/taille_moy_y],rayon/taille_moy_y);
%         elseif strcmp(forme,'plaque');
%             rectangle('Position', [(centre_x-width/2)/taille_moy_x, (centre_y-height/2)/taille_moy_y, width/taille_moy_x, height/taille_moy_y]);       %[x(origin) y(origin) width height]
%         end
%         axis([-1 nb_grains_x+2 -1 nb_grains_y+2]);
%         %text=['ite = ' num2str(t) ',    t_{ite} =' num2str(temps_ite) ',    t_{tot} = ' num2str(temps_tot), ',    taille = ' num2str(taille_grille_x) 'x' num2str(taille_grille_y), ',    Distrib. = ' mat2str(prob_occ) ',    Re = ' num2str(Re(t_rel)) ',    (' num2str(nb_particules(t_rel)) '/' num2str(QM(t_rel)) ')'];
%         %title(text, 'fontsize', 10);
%         %xlabel('Position en x', 'fontsize', 12);
%         %ylabel('Position en y', 'fontsize', 12);
        
        
    %FIGURE 3 - VITESSE ET DENSITÉ MOYENNE
        gcf3=figure (3);
        if strcmp(res_on,'on')
            set(gcf3,'Position', res3)
        end
        subplot(2,1,1)
        pcolor(v_x);
        colorbar
        
        title({text, 'Vitesse moyenne par noeud (pour 1 grain) [vitesse/noeud]'},'fontsize',9);
        set(gca,'YTick',[],'XTick',[],'box','off')
        %xlabel('Position en x');
        %ylabel('Position en y');
   
        subplot(2,1,2)
        pcolor(rho_moy);
        colorbar
        title('Densité moyenne par noeud (pour 1 grain) [#particules/noeud]');
        set(gca,'YTick',[],'XTick',[],'box','off')
        %xlabel('Position en x');
        %ylabel('Position en y');   
       
%         subplot(4,1,3)
%         pcolor(curl_amplitude_back);
%         colorbar
%         title('Vorticité sans background');
%         set(gca,'YTick',[],'XTick',[],'box','off')
%         
%         subplot(4,1,4)
%         pcolor(curl_amplitude);
%         colorbar
%         title('Vorticité');
%         set(gca,'YTick',[],'XTick',[],'box','off')
        
        %Quantité de mouvement
        x=1:maj_macro:maj_macro*t_rel;
        ligne=zeros(1,length(x));
        figure(5)
        subplot(2,1,1)
        plot(x,QM_x); hold on
        plot(x,ligne)
        title('QM en x');
        hold off
        
        subplot(2,1,2)
        plot(x,QM_y); hold on
        plot(x,ligne)
        title('QM en y');
        hold off
        
        %QM_x_haut=mean(v_x(1,:));
        %QM_x_bas=mean(v_x(numy,:));
        
        %fprintf('QM haut = %2.1f, QM bas = %2.1f\n', QM_x_haut*100, QM_x_bas*100);
        
  
   pause(temps_pause);
   
   %%%%%%%%%% ENREGISTREMENT DES DONNÉES %%%%%%%%%
        
        %IMAGE
        if ~rem(t,maj_img)
            saveas(gcf1,[nom_img1 '_' num2str(t)] ,'fig');
            saveas(gcf3,[nom_img3 '_' num2str(t)] ,'fig');
        end

        %VIDÉO
        if ~rem(t,maj_vid)
            %frame=getframe(figure (1));
            %writeVideo(video1,frame);
            
            %frame=getframe(figure (3));
            %writeVideo(video3,frame);
        end

        %FICHIERS
        if ~rem(t,maj_fich)
            %Workspace
            save([emplacement 'systeme_' num2str(t)], '-regexp', '^(?!(gcf1|gcf3|handlepushbutton|video1|video3)$).' );
        end
        
     end
            
   
   %Boutton d'arrêt
   drawnow 
   if ~ishandle(handlepushbutton)
        close(video1); close(video3);
       arret=1;
        break;
   end

end  

if arret~=1
	close(video1); close(video3);
end
