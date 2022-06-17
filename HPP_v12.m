% IMPLÉMENTATION HPP
% v12

%Ajouts v08 :
% - QM, enregistrement vidéo fonctionnel, redéfinition des moyennes
%(vitesse,densité)
% - 3e figure où la vitesse moyenne est soustraite

%Ajouts v09:
% - Enregistrement vidéo (2 figures)
% - Améloration de la présentation des résultats
% - Enregistrement du nb. de particules et QM dans .txt
% - Petite correction collisions 'Tous les noeuds' (~obs que j'avais
% enlevé)

%Ajouts v10:
% - Positionnement des obstacles

%Ajouts v11:
% - Partie enregistrement des données
% - Enregistrement .eps et .fig (3 figures)
% - Enregistrement .csv (nb. particules, QM, Re)
% - Enregistrement .csv (vitesses moyennes x et y)
% - Pas de collisions entre particules pour les noeuds des parois du haut et du bas
% - Vitesse du son et nb. de Reynold peut-être pas à jour
% - Plot de la vorticité

%Ajouts v12:
% - Exportation du workspace au complet uniquement


clc; clear all;

t_max=400;                  %Nb. d'itérations
taille_grille_x=800;       %Taille de la grille (doit être multiple de taille_moy)
taille_grille_y=500;        %Doit être multiple de 6 à cause de l'obstacle aussi...
taille_moy_x=10;            %Taille du moyennage
taille_moy_y=10;                            
temps_pause=0;              %Temps d'attente avant update figure [s]
maj_macro=50;                %Mise à jour propriété macroscopiques
maj_vid=200;                  %Mise à jour vidéo
maj_img=200;                  %Mise à jour images .eps et .fig
maj_fich=200;                 %Mise à jour fichiers
forme='cylindre';           %Forme de l'obstacle (cylindre, pas d'obstacle, plaque) 
emplacement='/Users/marc-antoinehuet/Desktop/Résultats finaux';
nom_video1=[emplacement 'fig1'];
nom_video3=[emplacement 'fig3'];
nom_img1=nom_video1;
nom_img3=nom_video3;

prob_occ = [30 70 30 30];

%Bouton d'arrêt
handlepushbutton = uicontrol('Style', 'PushButton', 'String', 'Arrêt boucle', ...
                        'Callback', 'delete(gcbf)');
arret=0;

%Enregistrement de la vidéo et du fichier .txt
res1=[0 0 1600 900];       %'Résolution' des vidéo
res3=[0 0 1600 900];
res_on='off';

video1=VideoWriter(nom_video1);
video3=VideoWriter(nom_video3);
video1.FrameRate=5;
video3.FrameRate=5;

open(video1); open(video3); 


%Il existe 3 types de noeuds : frontières (paroi du haut, du bas, entrée,
%sortie du flux), intérieur du domaine et obstacle. Une matrice contient
%l'information sur obstacle/pas obstacle, 1=obstacle, 0=pas obstacle.

%Le système est représenté par une matrice 3D. Pour chaque noeud, mat(i,j,k) 
%où i=position verticale, j=position horizontale, k=direction.

%-------------------- INITIALISATION DE LA GRILLE -------------------------

numx=taille_grille_x;         %Nombre de noeuds en x et en y
numy=taille_grille_y;

%             1
%             |
%         4 - 0 - 2
%             |
%             3

haut=zeros(numy,numx);  
bas=zeros(numy,numx);  
gauche=zeros(numy,numx);  
droite=zeros(numy,numx);  

%------------------------ DÉFINITION OBSTACLE -----------------------------

[columnsInImage, rowsInImage] = meshgrid(1:numx, 1:numy);

centre_y = round(numy/2);

%Forme de l'obstacle
if strcmp(forme,'cylindre')
    centre_x = round(numx*0.25);
    rayon = 33;
    obs = double((rowsInImage - centre_y).^2 + (columnsInImage - centre_x).^2 <= rayon.^2);
    dimension_obs=rayon*2;

elseif strcmp(forme,'plaque')
    centre_x = round(numx*0.2);
    width=1;
    height=66;
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



for k=1:4
    pos_occ=find(randi(100,numy,numx)<=prob_occ(k) & ~obs & ~parois);
    if k==1
    	haut(pos_occ)=1;
    elseif k==2
        droite(pos_occ)=1;
    elseif k==3 
    	bas(pos_occ)=1;
    elseif k==4
    	gauche(pos_occ)=1;
    end
end

%On élimine les particules vers le bas (paroi du haut) et vers le haut
%(paroi du bas)
haut(numy,:)=0;
bas(1,:)=0;

%Nombre de particules initial
%nb_particules(1)=sum(sum(droite))+sum(sum(gauche))+sum(sum(haut))+sum(sum(bas));
%fprintf('nb de particules = %d\n', nb_particules(1));


%--------------------MISE À JOUR DE L'ÉTAT DU SYSTÈME----------------------
temps_tot=0;
tic

[gridx,gridy]=meshgrid(1:numx,1:numy);
for t=1:t_max  
    %%%%%------------------- PHASE 1 : COLLISIONS -------------------%%%%%%
    droite_c=droite;        %Copies
    gauche_c=gauche;
    haut_c=haut;
    bas_c=bas;

    %-----TOUS LES NOEUDS-----%

    %Collision frontale 1
    pos_col=find(haut_c & bas_c & ~gauche_c & ~droite_c & ~obs & ~parois);
    haut(pos_col)=0; 
    bas(pos_col)=0;
    gauche(pos_col)=1;
    droite(pos_col)=1;
     
    %Collision frontale 2
    pos_col=find(~haut_c & ~bas_c & gauche_c & droite_c & ~obs & ~parois);
    haut(pos_col)=1; 
    bas(pos_col)=1;
    gauche(pos_col)=0;
    droite(pos_col)=0;

    %-----RÉFLEXIONS PAROIS DU HAUT ET DU BAS-----%

    %Paroi du haut
    i=numy;
    x=find(haut_c(i,:));
    bas(i,x)=1;
    haut(i,x)=0;
    
    %Paroi du bas
    i=1;
    x=find(bas_c(i,:));
    bas(i,x)=0;
    haut(i,x)=1;

    %-----RÉFLEXIONS OBSTACLE-----%

    [y,x] = find(obs==1);
    for i=1:length(x)
        if droite_c(y(i),x(i))==1            %Rebond vers la gauche
            gauche(y(i),x(i))=1; 
            droite(y(i),x(i))=0;
        end
        if gauche_c(y(i),x(i))==1            %Rebond vers la droite
            droite(y(i),x(i))=1;
            gauche(y(i),x(i))=0;
        end
        if haut_c(y(i),x(i))==1            %Rebond vers le bas
            bas(y(i),x(i))=1;
            haut(y(i),x(i))=0;
        end
        if bas_c(y(i),x(i))==1            %Rebond vers le haut
            haut(y(i),x(i))=1;
            bas(y(i),x(i))=0;
        end
    end

    %%%%%------------------- PHASE 2 : PROPAGATION --------------------%%%%
    
    %Les particules sont propagées du noeud (i,j) vers les voisins
    
    droite_c=droite;        %Copies
    gauche_c=gauche;
    haut_c=haut;
    bas_c=bas;

    droite=zeros(numy,numx);    %Réinitialisation
    gauche=zeros(numy,numx);
    haut=zeros(numy,numx);
    bas=zeros(numy,numx);
    
    %-------Propagation vers la droite. Exclusion : frontière droite-------

    [y,x]=find(droite_c & gridx~=numx);
    for i=1:length(x)
        droite(y(i),x(i)+1)=1;
    end

    %-------Propagation vers la gauche. Exclusion : frontière gauche-------

    [y,x]=find(gauche_c & gridx~=1);
    for i=1:length(x)
        gauche(y(i),x(i)-1)=1;
    end
    
    %----------------------Propagation vers le haut------------------------
    
    [y,x]=find(haut_c & gridy~=numy);
    for i=1:length(x)
        haut(y(i)+1,x(i))=1;
    end
    
     %----------------------Propagation vers le bas------------------------

    [y,x]=find(bas_c & gridy~=1);
    for i=1:length(x)
        bas(y(i)-1,x(i))=1;
    end
     

     %----------------------Conditions périodiques--------------------------
     
    %Frontière de gauche
    y=find(gauche_c(:,1));
    for i=1:length(y)
        gauche(y(i),numx)=1;
    end
    
    %Frontière de droite
    y=find(droite_c(:,numx));
    for i=1:length(y)
        droite(y(i),1)=1;
    end

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
                 direction_d=sum(sum(droite(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_g=sum(sum(gauche(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_h=sum(sum(haut(pos_y1:pos_y2, pos_x1:pos_x2)));
                 direction_b=sum(sum(bas(pos_y1:pos_y2, pos_x1:pos_x2)));

                 %Vitesse de chaque grain
                 v_x(i,j)=direction_d-direction_g;        
                 v_y(i,j)=direction_h-direction_b;
                 v_moy(i,j)=sqrt((v_x(i,j)^2+v_y(i,j)^2))/nb_noeuds_grain;  %Vitesse moyenne par noeud pour 1 grain
                 
                 %Densité moyenne par noeud pour 1 grain (particules/noeud)
                 rho_moy(i,j)=(direction_d+direction_g+direction_b+direction_h)/nb_noeuds_grain;     
             end
         end
         
         %Vitesses moyennes totales
         v_moy_moy=mean(mean(v_moy));   %Vitesse moyenne par noeud totale
         v_moyx=mean(mean(v_x));              %Vitesse moyenne par grain totale (en x)
         v_moyy=mean(mean(v_y));              %Vitesse moyenne par grain totale (en y)
         
         %Nombre de particules total
         nb_particules(t_rel)=sum(sum(droite))+sum(sum(gauche))+sum(sum(haut))+sum(sum(bas));
         %fprintf('nb de particules = %d\n', nb_particules(t_rel));
         
         %Quantité de mouvement totale
         QM_x(t_rel)=sum(sum(v_x));
         QM_y(t_rel)=sum(sum(v_y));
         QM(t_rel)=sqrt(QM_x(t_rel)^2+QM_y(t_rel)^2);
         %fprintf('QM = %.1f\n', QM(t_rel));
         
         %Nombre de Reynolds
            % Re = VL/nu
            % Vitesse = vitesse moyenne par noeud
            % Dimension = taille_obstacle/numy
            % Viscosité cinématique = 1/(2*densité)
        d=mean(mean(rho_moy))/4;                        %Densité par cellule
        cin_viscosity=1/(2*d);
        Re(t_rel)=v_moy_moy*dimension_obs/cin_viscosity;
        %fprintf('Re= %.1f\n', Re(t_rel));
        
        %Vorticité
        [curlx,curly]=curl(v_x,v_y);
        curl_amplitude=sqrt(curlx.^2+curly.^2);

      
    %Mise à jour des figures
    %FIGURE 1 - CHAMP DE VITESSE STANDARD
        gcf1=figure(1);
        if strcmp(res_on,'on')
            set(gcf1,'units','pixels','Position', res1)
        end
        subplot(2,1,1);
        x=1:nb_grains_x;
        y=1:nb_grains_y;
        quiver(x,y,v_x,v_y); hold on; 
        
        temps_ite=toc;
        temps_tot=temps_tot+temps_ite;
        tic
        
        %Formattage des propriétés
        temps_ite=round(temps_ite,1);
        temps_tot=round(temps_tot,1)/60;
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
        
            
    %FIGURE 1 - CHAMP DE VITESSE SANS BACKGROUND (NE PAS MODIFIER!!!!)
        %figure(2)
        subplot(2,1,2);
        x=1:nb_grains_x;
        y=1:nb_grains_y;
        quiver(x,y,v_x-v_moyx,v_y-v_moyy); hold on;      %Soustraction du background
        
        %Parois et obstacle
        plot([0; nb_grains_x+1], [0; 0], 'r-');       %paroi du bas
        plot([0; nb_grains_x+1], [nb_grains_y+1; nb_grains_y+1], 'r-');    %paroi du haut
        set(gca,'YTick',[],'XTick',[],'box','off','xcolor','w','ycolor','w')
        hold off
        if strcmp(forme,'cylindre')
            viscircles([centre_x/taille_moy_x centre_y/taille_moy_y],rayon/taille_moy_y);
        elseif strcmp(forme,'plaque');
            rectangle('Position', [(centre_x-width/2)/taille_moy_x, (centre_y-height/2)/taille_moy_y, width/taille_moy_x, height/taille_moy_y]);       %[x(origin) y(origin) width height]
        end
        axis([-1 nb_grains_x+2 -1 nb_grains_y+2]);
        %text=['ite = ' num2str(t) ',    t_{ite} =' num2str(temps_ite) ',    t_{tot} = ' num2str(temps_tot), ',    taille = ' num2str(taille_grille_x) 'x' num2str(taille_grille_y), ',    Distrib. = ' mat2str(prob_occ) ',    Re = ' num2str(Re(t_rel)) ',    (' num2str(nb_particules(t_rel)) '/' num2str(QM(t_rel)) ')'];
        %title(text, 'fontsize', 10);
        %xlabel('Position en x', 'fontsize', 12);
        %ylabel('Position en y', 'fontsize', 12);
        
        
    %FIGURE 3 - VITESSE ET DENSITÉ MOYENNE
        gcf3=figure (3);
        if strcmp(res_on,'on')
            set(gcf3,'units','pixels','Position', res3)
        end
        subplot(3,1,1)
        pcolor(v_moy);
        colorbar
        title({text,'Vitesse moyenne par noeud (pour 1 grain) [vitesse/noeud]'},'fontsize',9);
        set(gca,'YTick',[],'XTick',[],'box','off')
        %xlabel('Position en x');
        %ylabel('Position en y');
   
        subplot(3,1,2)
        pcolor(rho_moy);
        colorbar
        title('Densité moyenne par noeud (pour 1 grain) [#particules/noeud]');
        set(gca,'YTick',[],'XTick',[],'box','off')
        %xlabel('Position en x');
        %ylabel('Position en y');   
        
        subplot(3,1,3)
        pcolor(curl_amplitude);
        colorbar
        title('Vorticité (amplitude)');
        set(gca,'YTick',[],'XTick',[],'box','off')
        
        %Quantité de mouvement
        x=1:maj_macro:maj_macro*t_rel;
        figure(5)
        subplot(2,1,1)
        plot(x,QM_x);
        title('QM en x');
        
        subplot(2,1,2)
        plot(x,QM_y);
        title('QM en y');
        
        pause(temps_pause);
        
       %%%%%%%%%% ENREGISTREMENT DES DONNÉES %%%%%%%%%
        
        %IMAGE
        if ~rem(t,maj_img)
            saveas(gcf1,[nom_img1 '_' num2str(t)] ,'fig');
            saveas(gcf3,[nom_img3 '_' num2str(t)] ,'fig');
        end

        %VIDÉO
        if ~rem(t,maj_vid)
            %frame=getframe(gcf1);
            %writeVideo(video1,frame);
            
            %frame=getframe(gcf3);
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
