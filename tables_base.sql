--TABLE BANQUE 
DROP TABLE IF EXISTS Banque CASCADE;
CREATE TABLE Banque (
    id_banque serial PRIMARY KEY,
    nom varchar(20) NOT NULL,
    adresse varchar(50) NOT NULL,
    prix_virement numeric(20,2) NOT NULL check (prix_virement>= 0.5 and prix_virement<=7), --prix d'un virement periodique
    forfait_virement numeric(20,2) NOT NULL check(forfait_virement>=2 and forfait_virement<=3), --prix du forfait virement
    forfait_carte_retrait numeric(20,2) NOT NULL check(forfait_carte_retrait >= 1 and forfait_carte_retrait <=2),--normal ou systematique
    forfait_carte_pni numeric(20,2) NOT NULL check(forfait_carte_pni > 2 and forfait_carte_pni <=3),--national immediat
    forfait_carte_pnd numeric(20,2) NOT NULL check(forfait_carte_pnd > 3 and forfait_carte_pnd <=3.3),--national differe
    forfait_carte_pii numeric(20,2) NOT NULL check(forfait_carte_pii > 3 and forfait_carte_pii <=3.3),--international immediat
    forfait_carte_pid numeric(20,2) NOT NULL check(forfait_carte_pid > 3.3 and forfait_carte_pid <=4),--international differe
    forfait_carte_gold numeric(20,2) NOT NULL check(forfait_carte_gold > 8.3 and forfait_carte_gold <=10.8),
    plafond_operation numeric(20,2) NOT NULL,--plafond de la banque par operation
    plafond_semaine numeric(20,2) NOT NULL--plafond de la banque par semaine
);


--TABLE AGENCE
DROP TABLE IF EXISTS Agence CASCADE;
CREATE TABLE Agence (
    id_agence serial,
    id_banque integer references Banque(id_banque),
    nom varchar(20) NOT NULL,
    adresse varchar(50) NOT NULL,
    PRIMARY KEY(id_agence, id_banque)
);


--TABLE CLIENT
DROP TABLE IF EXISTS Client CASCADE;
CREATE TABLE Client (
    id_client serial PRIMARY KEY, 
    nom varchar(20) NOT NULL,
    prenom varchar(20) NOT NULL,
    age integer NOT NULL,
    UNIQUE(nom,prenom,age) 
);


--TABLE TYPE_COMPTE
DROP TABLE IF EXISTS Type_compte CASCADE;
CREATE TABLE Type_compte (
    num_type serial PRIMARY KEY,
    nom_type varchar,
    min_remuneration numeric(20,2) default 1 CHECK(min_remuneration >= 1), -- montant à partir duquel on rémunère, différent selon le tye du compte
    taux_remuneration numeric(20,2)  default 0.10 CHECK(taux_remuneration >= 0.10 and taux_remuneration <= 0.75), -- taux de remuneration
    periode varchar(9) not null CHECK(periode = 'quinzaine' OR periode = 'quotidien'),-- periode de remuneration
    decouvert_autorise numeric(20,2) NOT NULL CHECK(decouvert_autorise<=0)
);


--TABLE COMPTE
DROP TABLE IF EXISTS Compte CASCADE;
CREATE TABLE Compte (
    id_compte varchar(23) PRIMARY KEY,
    iban varchar(27) NOT NULL,
    bic varchar(11) NOT NULL,
    solde numeric(20,2) default 0,
    tolerance boolean DEFAULT 'false',
    gele boolean DEFAULT 'false', -- savoir si un compte est gelé ou non 
    id_agence integer,
    id_banque integer,
    num_type integer references Type_compte(num_type),
    id_carte integer references Type_carte(id_carte),
    plafond_mineur numeric(20,2),--plafond par semaine choisi par les parents pour un client mineur
    plafond_semaine numeric(20,2),--retrait effectues depuis le debut de la semaine, il est reinitiliase a 0 chaque lundi et est incremente a chaque retrait en distributeur
    etou varchar not null check(etou = 'et' or etou = 'ou'),--type et ou ou pour un compte joint
    foreign key (id_agence, id_banque) references Agence(id_agence, id_banque),
    UNIQUE(iban, bic)
);


--TABLE RELEVE
DROP TABLE IF EXISTS Releve CASCADE;
CREATE TABLE Releve (
    id_operation serial,
    date_operation date NOT NULL,
    nom_operation varchar(20) CHECK( nom_operation='retrait' OR nom_operation = 'depot cheque' OR nom_operation='emission cheque' OR nom_operation = 'depot liquide' OR nom_operation = 'virement' OR nom_operation='forfait virement' or nom_operation = 'retrait distributeur' or nom_operation = 'achat national' or nom_operation = 'achat international' or nom_operation='forfait carte' or nom_operation='achat differe'),
    montant numeric(20,2) NOT NULL,
    id_compte varchar(23) references Compte(id_compte) ,
    PRIMARY KEY (id_operation, id_compte)
);


--INTERDIT BANQUAIRE
DROP TABLE IF EXISTS interdit_bancaire CASCADE;
CREATE TABLE interdit_bancaire (
    id_ib serial,
    id_client integer references client(id_client),
    id_banque integer references Banque(id_banque),
    motif varchar,
    date_interdit date NOT NULL,
    date_regularisation date DEFAULT NULL,
    PRIMARY KEY(id_ib, id_client)
);

--TABLE VIREMENT
DROP TABLE IF EXISTS virement CASCADE;
CREATE TABLE Virement (
    id_virement serial PRIMARY KEY,
    date_debut date NOT NULL,--date souhaitee par le client pour effectue le virement
    date_fin date CHECK(date_fin >= date_debut),-- date_fin = date_debut pour un virement unique, date où sera effectue le dernier virement sion
    periodicite varchar(13) CHECK(periodicite = 'mensuelle' OR periodicite = 'trimestrielle' OR periodicite = 'semestrielle' OR periodicite = 'annuelle' OR periodicite='unique'),
    montant integer NOT NULL,
    emetteur varchar(23) references compte(id_compte) ,--id_compte de l'emetteur
    recepteur varchar(23) references compte(id_compte) --id_compte du recepteur
);

--TABLE CALENDRIER
DROP TABLE IF EXISTS calendrier CASCADE;
CREATE TABLE calendrier (
	d date primary key check (d >= CURRENT_DATE)
);

--EN ATTENTE virement
DROP TABLE IF EXISTS attente_virement CASCADE; --table qui enregistre les virements en attente
CREATE TABLE attente_virement (
	id_attenteVirement serial primary key,
	d_prevue date NOT NULL, --date a laquelle doit etre effectue le virement
	d_fin date NOT NULL, -- = d_prevue si virement unique
	somme numeric(20,2) NOT NULL,
	em varchar(23),--l'id du compte emetteur du virement
	iban_rec varchar(27), --l'iban du compte recepteur du virement
	bic_rec varchar(11),--le bic du compte recepteur du virement
	periodicite varchar(13),--periodicite du virement
	prix_virement numeric(20,2) not null
);

--EN ATTENTE forfaits
DROP TABLE IF EXISTS attente_forfait CASCADE; -- table qui enregistre les operations en attente
CREATE TABLE attente_forfait (
	id_attenteForfait serial primary key,
	d_prevue date not null,--date a laquelle l'operation est censee etre effectuee
	type varchar not null check (type='releve' or type='forfait virement' or type='forfait decouvert' or type='forfait agio' or type='remuneration1' or type='remuneration2' or type = 'forfait retrait' or type = 'forfait national immediat' or type = 'forfait national differe' or type = 'forfait international immediat' or type = 'forfait international differe' or type = 'forfait gold'),
	id_compte varchar(23) references compte(id_compte)  
);

--TABLE TYPE_CARTE
DROP TABLE IF EXISTS type_carte CASCADE;
CREATE TABLE type_carte(
	id_carte serial primary key,
	type_autorisation varchar not null check (type_autorisation='systematique' or type_autorisation='normal'),
	type_carte varchar not null check (type_carte = 'retrait' or type_carte = 'paiement national immediat' or type_carte = 'paiement national differe' or type_carte = 'paiement international immediat' or type_carte = 'paiement international differe' or type_carte = 'paiement gold')
);

--TABLE DIFFERE
DROP TABLE IF EXISTS differe CASCADE;
CREATE TABLE differe(
       id_differe serial primary key,
       type varchar not null check (type = 'achat' or type = 'forfait carte'), 
       montant numeric(20,2) not null, 
       id_compte varchar references compte(id_compte)
);

--TABLE TITULAIRE
DROP TABLE IF EXISTS Titulaire CASCADE;
CREATE TABLE Titulaire (
    id_client integer references Client(id_client),
    id_compte varchar(23) references Compte(id_compte),
    responsable boolean DEFAULT 'false',
    mandataire boolean DEFAULT 'false',
    date_fin date CHECK (date_fin > CURRENT_DATE),--la date jusqua laquelle un co-titulaire est mandataire, pour le cas des responsables ou simple co-titulaire la date est celle d'ouverture du compte + 100 ans
    PRIMARY KEY(id_client, id_compte)
);
