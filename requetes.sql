--VIDE BASE
delete from virement;
delete from compte;
delete from interdit_bancaire;
delete from client;
delete from type_compte;
delete from type_carte;
delete from releve;
delete from agence;
delete from banque;
delete from differe;
delete from attente_forfait;
delete from attente_virement;


--DATE
insert into calendrier values (current_date);

--BANQUE
insert into Banque (nom, adresse, prix_virement, forfait_virement, forfait_carte_retrait,forfait_carte_pni,
forfait_carte_pnd,forfait_carte_pii, forfait_carte_pid,forfait_carte_gold, plafond_operation, plafond_semaine) 
values( 'lcl', '1 rue du carton Paris', 5, 2, 1, 2.1, 3.1, 3.1, 3.5, 9, 500, 1500);

insert into Banque (nom, adresse, prix_virement, forfait_virement, forfait_carte_retrait,forfait_carte_pni,
forfait_carte_pnd,forfait_carte_pii, forfait_carte_pid,forfait_carte_gold, plafond_operation, plafond_semaine) 
values( 'Caisse epargne', '8 rue du chemin de fer Strasbourg', 6, 3, 1.1, 2.1, 3.2, 3.1, 3.6, 9.5, 800, 2000);

insert into Banque(nom, adresse, prix_virement, forfait_virement, forfait_carte_retrait,forfait_carte_pni,
forfait_carte_pnd,forfait_carte_pii, forfait_carte_pid,forfait_carte_gold, plafond_operation, plafond_semaine) 
values('credit agricole', '102 rue Netter Carcassonne', 4, 2.5, 1.2, 2.1, 3.3, 3.2, 3.8, 10, 450, 2200);

--AGENCE
insert into Agence (id_banque, nom, adresse) values( 1, 'lcl paris', '2 rue des bonbons Paris ');
insert into Agence (id_banque, nom, adresse) values( 1, 'lcl Lyon', '25 AV des ordinateurs Lyon');
insert into Agence (id_banque, nom, adresse) values( 1, 'lcl Colmar', '87 rue Berthillon Colmar');
insert into Agence (id_banque, nom, adresse) values( 2, 'Epargne Bordeaux', '3 rue des tulipes Bordeaux');
insert into Agence (id_banque, nom, adresse) values( 2, 'Epargne Narbonne', '25 AV des ecoliers Narbonne');
insert into Agence (id_banque, nom, adresse) values( 3, 'Agriculture Paris', '6 rue Diderot Paris ');
insert into Agence (id_banque, nom, adresse) values( 3, 'Agriculture Lille', '201 rue des anglais Lille');

--CLIENT
insert into Client(nom, prenom, age) values ('Violon', 'Tatiana', 45); 
insert into Client(nom, prenom, age) values ('Lachaise', 'Julien', 55); 
insert into Client(nom, prenom, age) values ('Schneider', 'Guilia', 25);
insert into Client(nom, prenom, age) values ('Yann', 'Fabrice', 35); 
insert into Client(nom, prenom, age) values ('Genele', 'Thomas', 107); 
insert into Client(nom, prenom, age) values ('Violas', 'Luc', 80); 
insert into Client(nom, prenom, age) values ('Schneider', 'Paul', 31);
insert into Client(nom, prenom, age) values ('Gary', 'Melissa', 14); 
insert into Client(nom, prenom, age) values ('Legrand', 'Cynthia', 20);
insert into Client(nom, prenom, age) values ('Hirsch', 'Adeline', 22);
insert into Client(nom, prenom, age) values ('Gunter', 'Cecilia', 87);

--TYPE COMPTE
insert into Type_compte (nom_type, min_remuneration, taux_remuneration, periode, decouvert_autorise) 
values ('Livret A', 1, 0.75, 'quotidien', 0);
insert into Type_compte (nom_type, min_remuneration, taux_remuneration, periode, decouvert_autorise) 
values ('Compte courant + Carte retrait ', 1000, 0.2, 'quinzaine', -200);
insert into Type_compte (nom_type, min_remuneration, taux_remuneration, periode, decouvert_autorise) 
values ('Compte courant + Carte paiement', 1000, 0.2, 'quinzaine', -300);
insert into Type_compte (nom_type, min_remuneration, taux_remuneration, periode, decouvert_autorise) 
values ('Compte Entreprise/Association + Carte paiement', 2000, 0.2, 'quinzaine', -1000);

--TYPE CARTE
insert into type_carte (type_autorisation, type_carte) values ('systematique', 'retrait');
insert into type_carte (type_autorisation, type_carte) values ('normal', 'retrait');
insert into type_carte (type_autorisation, type_carte) values ('normal', 'paiement national immediat');
insert into type_carte (type_autorisation, type_carte) values ('normal', 'paiement national differe');
insert into type_carte (type_autorisation, type_carte) values ('normal', 'paiement international immediat');
insert into type_carte (type_autorisation, type_carte) values ('normal', 'paiement international differe');
insert into type_carte (type_autorisation, type_carte) values ('normal', 'paiement gold');

--COMPTE
--idclient, idagence, idbanqu6e, idcompte, iban, bic, typecompte, somme, plafond mineur, type carte, joint, etou
select ouverture_compte(1, 7, 3, '123456', 'FR12345', '321' , 2, 300, 500, 3, 'f', 'ou'); --tatiana
select ouverture_compte(2, 7, 3, '123654', 'FR12354', '322' , 2, 1500, 0, 2 , 'f', 'ou'); --julien
select ouverture_compte(3, 5, 2, '321456', 'FR55345', '381' , 3, 50, 0, 1, 'f', 'ou'); --Guilia
select ouverture_compte(4, 4, 2, '789456', 'FR44345', '771' , 3, 1000,0, 4, 'f', 'ou'); --fabrice
select ouverture_compte(4, 1, 1, '711156', 'FR41105', '011' , 3, 620,0, 5, 'f', 'ou'); --fabrice
select ouverture_compte(4, 4, 2, '722156', 'FR42205', '211' , 3, 20,0, 6, 'f', 'ou'); --fabrice
select ouverture_compte(5, 2, 1, '712346', 'FR12105', '781' , 3, 100, 800, 7, 'f', 'ou');--thomas
select ouverture_compte(6, 2, 1, '456756', 'FR45675', '222' , 3, 1000,0, 7, 'f', 'ou');--luc
select ouverture_compte(7, 3, 1, '456788', 'FR40005', '000' , 3, 250,0, 7,'t', 'ou');--paul
select ouverture_compte(8, 3, 1, '400788', 'FR00005', '070' , 3, 5000,0,7,'f', 'ou');--Melissa
select ouverture_compte(9, 2, 1, '799346', 'FR12805', '781' , 3, 100,0, 7,'f', 'ou');--Cynthia
select ouverture_compte(9, 2, 1, '456996', 'FR00075', '222' , 1, 1000,0, 1,'f', 'ou');--Cynthia
select ouverture_compte(10, 3, 1, '006788', 'FR49905', '210' , 3, 2000,0,7,'f', 'ou');--Adeline
select ouverture_compte(10, 3, 1, '000788', 'FR99905', '073' , 1, 180,0, 1,'f', 'ou');--Adeline
select ouverture_compte(11, 3, 1, '100788', 'FR19905', '173' , 1, 180,0, 1,'t', 'et');--Cecilia

--COMPTE JOIN
select ajout_titulaire('456788','Lachaise', 'Julien', 55);--compte ou partage avec paul
select ajout_responsable('456788','Lachaise', 'Julien', 55);

select ajout_titulaire('100788', 'Genele', 'Thomas', 107);--compte et partage avec Cecilia

--ATTENTE FORFAIT
insert into attente_forfait (d_prevue, type) values (current_date, 'forfait virement'); 
insert into attente_forfait (d_prevue, type) values (current_date, 'remuneration1');
insert into attente_forfait (d_prevue, type) values (current_date, 'remuneration2');
insert into attente_forfait (d_prevue, type) values ('2014-02-01', 'releve');




