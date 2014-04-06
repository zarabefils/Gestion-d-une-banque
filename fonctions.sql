-- ***** INSERER UN CLIENT *****
CREATE OR REPLACE FUNCTION insert_client(n varchar(20), p varchar(20), a integer) RETURNS VOID
AS $$ 
	BEGIN
	INSERT INTO projet_hirsch.client (nom, prenom, age) VALUES (n,p,a);
   	END
$$ LANGUAGE 'plpgsql';


-- ***** VERIFIER LE CHOIX DE COMPTE ET CARTE DU CLIENT *****
CREATE OR REPLACE FUNCTION verif_choix(cl integer, typecpp integer, typecar integer) RETURNS INTEGER
AS $$ 
	DECLARE 
	ageCl integer;
	BEGIN
		SELECT age into ageCl from client where id_client = cl;
		IF typecpp = 1 AND typecar <> 0 THEN 
			RAISE NOTICE 'Desole mais vous ne pouvez choisir aucune carte avec ce type de compte, operation d ouverture du compte annulee';
			RETURN 0;
		ELSIF typecpp = 2 AND typecar <> 1 AND typecar <> 2 THEN 
			RAISE NOTICE 'Desole mais vous ne pouvez choisir qu une carte de retrait avec ce type de compte, operation d ouverture annulee';
			RETURN 0;
		ELSIF (typecpp = 3 OR typecpp = 4) AND (typecar = 0 OR typecar = 1 OR typecar = 2) THEN 
			RAISE NOTICE 'Desole mais vous ne pouvez choisir qu une carte de paiement avec ce type de compte, operation d ouverture annulee';
			RETURN 0;
		ELSIF (typecpp = 3 OR typecpp = 4) AND ageCl < 18 THEN 
			RAISE NOTICE 'Desole mais ce type de compte est reserve aux personnes majeures, operation d ouverture du compte annulee';
			RETURN 0;
		ELSE 
			RAISE NOTICE 'L operation d ouverture du compte va pouvoir debuter';
			RETURN 1;
		END IF;  
   	END
$$ LANGUAGE 'plpgsql';


--**** OUVERTURE DUN COMPTE ****
CREATE OR REPLACE FUNCTION ouverture_compte (cl  integer, agence integer, banque integer,  cpp varchar(23), ib varchar(27), bi varchar(11), typ integer, argent numeric(20,2), plafondMin numeric(20,2), typec integer, joint boolean, et_ou varchar ) RETURNS INTEGER
AS $$
   	DECLARE
  	aujourdhui date;--date qui se trouve actuellement dans calendrier
   	typecarte varchar;--le type de carte qui sera recupere grace a typec 
   	plafond_b numeric(20,2);--le plafond de la banque pour une operation
   	ageCl integer;--l'age du client 
   	BEGIN
  	 	SELECT d INTO aujourdhui FROM calendrier;
   		SELECT banque.plafond_semaine INTO plafond_b FROM compte, banque WHERE compte.id_banque=banque.id_banque AND compte.id_compte=cpp;
  
   		IF (plafondMin<0 or plafondMin>=plafond_b) THEN --les parents ont donne un plafond inferieur a 0 ou superieur a celui par semaine de la banque
   			--on insere alors dans compte le nouveau compte avec le plafond de la banque pour une operation pour le plafond de l'enfant(plafond_mineur)
    		INSERT INTO compte (id_compte, iban, bic, solde, id_agence, id_banque, num_type, plafond_semaine, plafond_mineur, id_carte, etou) VALUES ( cpp, ib, bi,argent, agence, banque, typ, 0, plafond_b, typec, et_ou);
    		--a ce stade le client n est pas responsable ou mandataire pour le compte, il est seulement titulaire, les valeurs sont donc à false pour responsable et mandataire
    		INSERT INTO titulaire VALUES (cl, cpp,'f', 'f', aujourdhui + interval '100 years'); 
   		ELSE 
   			--les parents ont bien respectes les contraintes, le plafond_mineur aura pour valeur plafondMin
    		INSERT INTO compte (id_compte, iban, bic, solde, id_agence, id_banque, num_type, plafond_semaine, plafond_mineur, id_carte, etou) VALUES ( cpp, ib, bi,argent, agence, banque, typ, 0, plafondMin, typec, et_ou);
    		INSERT INTO titulaire VALUES (cl, cpp,'f', 'f', aujourdhui + interval '100 years');
   		END IF;

   		IF FOUND THEN
  		 	SELECT age INTO ageCl FROM client WHERE client.id_client=cl;
  		 	--contrainte de l'age pour les signatures
 			IF ageCl < 18  THEN RAISE NOTICE 'VOUS ETES MINEUR IL FAUT LA SIGNATURE DES PARENTS';
   			ELSE RAISE NOTICE 'VOTRE SIGNATURE';
   			END IF;

   			SELECT type_carte INTO typecarte FROM type_carte WHERE id_carte = typec;

   			--en fonction du type de carte choisi par le client, un forfait sera preleve chaque mois, chaque type de carte ayant un forfait different choisi par la banque
   			IF    typecarte='retrait'                         THEN INSERT INTO attente_forfait (d_prevue, type, id_compte) VALUES (aujourdhui, 'forfait retrait', cpp); 
   			ELSIF typecarte='paiement national immediat'      THEN INSERT INTO attente_forfait (d_prevue, type, id_compte) VALUES (aujourdhui, 'forfait national immediat', cpp);
   			ELSIF typecarte='paiement national differe'       THEN INSERT INTO attente_forfait (d_prevue, type, id_compte) VALUES (aujourdhui, 'forfait national differe', cpp); 
  			ELSIF typecarte='paiement international immediat' THEN INSERT INTO attente_forfait (d_prevue, type, id_compte) VALUES (aujourdhui, 'forfait international immediat', cpp);
  			ELSIF typecarte='paiement international differe'  THEN INSERT INTO attente_forfait (d_prevue, type, id_compte) VALUES (aujourdhui, 'forfait international differe', cpp);
  			ELSE 												   INSERT INTO attente_forfait (d_prevue, type, id_compte) VALUES (aujourdhui, 'forfait gold', cpp);
   			END IF;

   		RETURN 1;--utilise par notre interface java
   		ELSE RETURN 0;
   		END IF;	
   	END;
$$ LANGUAGE 'plpgsql';



--****FERMETURE COMPTE****
CREATE OR REPLACE FUNCTION fermeture_compte (  ccp varchar(23) ) RETURNS VOID
AS $$
	BEGIN
		DELETE FROM titulaire WHERE titulaire.id_compte=ccp; --supprime tout les titulaires du compte
		IF FOUND THEN
			DELETE FROM releve WHERE releve.id_compte=ccp;
			DELETE FROM virement WHERE virement.emetteur=ccp ;
			DELETE FROM virement WHERE virement.recepteur=ccp;
			DELETE FROM compte WHERE compte.id_compte=ccp ; --supprime le compte
			RAISE NOTICE'COMPTE SUPPRIME'  ;
   		END IF;
   END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION verif_fermeture() RETURNS TRIGGER AS $$
    DECLARE
	gel boolean;
	soldeCompte numeric(20,2);
	idC varchar;
	iban varchar;
	bic varchar;
	iban2 varchar;
	bic2 varchar;
	BEGIN
		SELECT gele, solde INTO gel, soldeCompte FROM compte WHERE compte.id_compte=old.id_compte;
		--on verifie que le solde du compte est bien egal a 0
		IF (soldeCompte!=0 )  THEN 
			RAISE EXCEPTION 'VOTRE COMPTE NE PEUT ETRE SUPPRIME';
			RETURN old;--operation de suppression annulee
		ELSE
			SELECT attente_virement.em INTO idC FROM attente_virement WHERE attente_virement.em = old.id_compte;
			IF FOUND THEN 
				RAISE EXCEPTION 'IMPOSSIBLE DE SUPPRIMER LE COMPTE VOUS AVEZ DES VIREMENTS A EFFECTUER';
				RETURN OLD;
			END IF;
			SELECT attente_virement.iban_rec, attente_virement.bic_rec, compte.iban, compte.bic  INTO iban, bic, iban2, bic2 FROM attente_virement, compte WHERE 
			compte.id_compte = old.id_compte and attente_virement.bic_rec=compte.bic and attente_virement.iban_rec=compte.iban;
			IF FOUND THEN 
				RAISE EXCEPTION 'IMPOSSIBLE DE SUPPRIMER LE COMPTE VOUS AVEZ DES VIREMENTS EN ATTENTE';
				RETURN OLD;
			END IF;
			SELECT differe.id_compte INTO idC FROM differe WHERE differe.id_compte = old.id_compte;
			IF FOUND THEN
				RAISE EXCEPTION 'IMPOSSIBLE DE SUPPRIMER CE COMPTE, VOUS AVEZ DES PAIEMENTS DIFFERES EN ATTENTE';
				RETURN OLD;
			END IF;
			RETURN NEW;--operation de suppression du compte effectuee   
		END IF; 
    END;
$$LANGUAGE 'plpgsql';


DROP TRIGGER IF EXISTS trig_fermeture ON titulaire;

CREATE TRIGGER trig_fermeture
       BEFORE DELETE
       ON titulaire
       FOR EACH ROW
       EXECUTE PROCEDURE verif_fermeture();


--***CONSULTATION SOLDE*****
CREATE OR REPLACE FUNCTION consultation(cl integer, ccp varchar(23)) RETURNS VOID
AS $$
	DECLARE
	somme numeric(20,2);
	BEGIN 
		SELECT solde INTO somme FROM compte natural join titulaire WHERE titulaire.id_client=cl AND compte.id_compte=ccp AND titulaire.id_compte = compte.id_compte;
		RAISE NOTICE 'VOUS AVEZ % EUROS SUR VOTRE COMPTE NUMERO % .', somme, ccp;
	END;
$$ LANGUAGE 'plpgsql';


--****INTERDIT BANCAIRE	****
CREATE OR REPLACE FUNCTION IB(cl integer, id_ban integer, msg varchar ) RETURNS VOID
AS $$
	DECLARE
	aujourdhui date;
	idCompte varchar(23);
	manda boolean;
	BEGIN
		SELECT d INTO aujourdhui FROM calendrier;--la date du jour sera enregistree dans date_interdit
		INSERT INTO interdit_bancaire (id_client, id_banque, motif, date_interdit, date_regularisation) VALUES (cl,id_ban, msg, aujourdhui, aujourdhui+interval'5 years');
		FOR idCompte, manda IN SELECT titulaire.id_compte FROM titulaire WHERE titulaire.id_client=cl
		LOOP 
				--on gele tous les comptes du client qui devient interdit bancaire
				UPDATE compte set gele='t', tolerance='f' WHERE compte.id_compte= idCompte;
		END LOOP;
		RAISE NOTICE 'Veuillez rendre votre chequier a la banque!';
	END;
$$ LANGUAGE 'plpgsql';

--*****VIREMENT******
CREATE OR REPLACE FUNCTION virement(somme numeric(20,2), em varchar(23), iban_rec varchar(27), bic_rec varchar(11), d_debut date, d_fin date, periodicite varchar(13)) RETURNS VOID
AS $$
	DECLARE
	prixVirement numeric(20,2);	
	aujourdhui date;
	et_ou varchar;
	BEGIN 

		SELECT d INTO aujourdhui FROM calendrier;
		PERFORM id_compte FROM compte WHERE iban = iban_rec AND bic = bic_rec;	
		IF NOT FOUND THEN RAISE NOTICE 'DESTINATAIRE INCONNU POUR LE VIREMENT';
		ELSE
			--verification du type de compte joint pour les signatures
			SELECT etou INTO et_ou FROM compte WHERE id_compte=em;
			IF(et_ou='et') THEN RAISE NOTICE'SIGNATURE DE TOUT LES TITULAIRES SVP';
			ELSE RAISE NOTICE'VOTRE SIGNATURE SVP'; 
			END IF;

			SELECT prix_virement INTO prixVirement FROM banque, compte WHERE compte.id_banque=banque.id_banque AND compte.id_compte=em;
			IF aujourdhui=d_debut THEN--le client souhaite effectuer un virement aujourd hui
				IF periodicite='unique' THEN--ce virement est unique
					PERFORM virement_unique(somme, em, iban_rec, bic_rec, d_debut);
				ELSE--ce virement est periodique
					PERFORM virement_periodique(somme,em,iban_rec, bic_rec, d_debut, d_fin, periodicite, prixVirement);
					IF periodicite='quinzaine' THEN 
						INSERT INTO attente_virement  (d_prevue ,d_fin, somme, em, iban_rec, bic_rec, periodicite , prix_virement) VALUES (d_debut+integer'1' ,d_fin ,somme ,em ,iban_rec , bic_rec ,periodicite, prixVirement );
					END IF; 
					IF periodicite= 'mensuelle' THEN
						INSERT INTO attente_virement  (d_prevue ,d_fin, somme, em, iban_rec, bic_rec, periodicite , prix_virement) VALUES (d_debut+interval'1 month' ,d_fin ,somme ,em ,iban_rec , bic_rec ,periodicite, prixVirement );
					END IF;
					IF periodicite='trimestrielle' THEN 
						INSERT INTO attente_virement  (d_prevue ,d_fin, somme, em, iban_rec, bic_rec, periodicite , prix_virement) VALUES (d_debut+interval'3 months' ,d_fin ,somme ,em ,iban_rec , bic_rec ,periodicite, prixVirement );
					END IF;
					IF periodicite='semestrielle' THEN 
						INSERT INTO attente_virement  (d_prevue ,d_fin, somme, em, iban_rec, bic_rec, periodicite , prix_virement) VALUES (d_debut+interval'6 months' ,d_fin ,somme ,em ,iban_rec , bic_rec ,periodicite, prixVirement );
					END IF;
					IF periodicite='annuelle' THEN 
						INSERT INTO attente_virement  (d_prevue ,d_fin, somme, em, iban_rec, bic_rec, periodicite , prix_virement) VALUES (d_debut+interval'1 year' ,d_fin ,somme ,em ,iban_rec , bic_rec ,periodicite, prixVirement );
					END IF;
				END IF;
			ELSE --le client souhaite effectuer son virement a une date choisie
				IF periodicite='unique' THEN
					--on enregistre les informations relatives au virement unique dans attente_virement qui sera etudiee lors de l'appel au triger verif_date	
					INSERT INTO attente_virement (d_prevue ,d_fin, somme, em, iban_rec, bic_rec, periodicite , prix_virement) VALUES (d_debut ,d_fin ,somme ,em ,iban_rec , bic_rec ,periodicite, 0 );
				ELSE
					--on enregistre les informations relatives au virement periodique dans attente_virement qui sera etudiee lors de l'appel au triger verif_date
					INSERT INTO attente_virement  (d_prevue ,d_fin, somme, em, iban_rec, bic_rec, periodicite , prix_virement) VALUES (d_debut ,d_fin ,somme ,em ,iban_rec , bic_rec ,periodicite, prixVirement );
				END IF;
			END IF;
		END IF;
	END;
$$ LANGUAGE 'plpgsql';

--***VIREMENT UNIQUE***
CREATE OR REPLACE FUNCTION virement_unique(somme numeric(20,2), em varchar(23), iban_rec varchar(27), bic_rec varchar(11), d date) RETURNS VOID
AS $$
	DECLARE
	compte_rec varchar(23);--id du compte recepteur
	ib boolean;--un booleen precisant si le client emetteur est interdit bancaire
	argent numeric(20,2);--la somme a virer
	mois integer;
	annee integer;
	d_virement date;
	aujourdhui date;
	BEGIN 

	SELECT calendrier.d INTO aujourdhui FROM calendrier;

	--test si le forfait a ete paye
	SELECT extract ( MONTH FROM aujourdhui) INTO mois;
	SELECT extract ( YEAR FROM aujourdhui) INTO annee;
    SELECT date_operation  INTO d_virement FROM releve WHERE nom_operation='forfait virement' AND ((SELECT extract (MONTH FROM date_operation) )= mois AND (SELECT extract (YEAR FROM date_operation) )= annee  AND id_compte=em);
	IF FOUND THEN

		--test interdit bancaire
		SELECT gele, solde INTO ib, argent FROM compte WHERE id_compte=em;
		IF ((ib='t' AND (argent-somme)>=0 ) or ib='f' )THEN--le client n'est pas interdit bancaire ou il l'est mais a suffisamment de provisions sur le compte
			UPDATE compte set solde = solde - somme WHERE id_compte=em;--le compte emetteur est debiter de somme 
			IF FOUND THEN
				UPDATE compte set solde = solde + somme WHERE bic=bic_rec AND iban=iban_rec;--le compte emetteur recoit somme
				SELECT id_compte INTO compte_rec FROM compte WHERE iban=iban_rec AND bic=bic_rec;
				--une operation a ete effectuee on l'enregistre dans virement et releve
				INSERT INTO virement (date_debut, date_fin, periodicite, montant, emetteur, recepteur) VALUES (d, d, 'unique', somme, em, compte_rec);
				INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (d, 'virement', -somme, em); 
				INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (d, 'virement', somme, compte_rec); 
			END IF;
		ELSE RAISE NOTICE 'INTERDIT BANCAIRE: IMPOSSIBLE D EFFECTUER UNE OPERATION QUI RENDE VOTRE SOLDE NEGATIF';
		END IF;
	ELSE RAISE NOTICE 'VIREMENT IMPOSSIBLE POUR NON PAIEMENT DU FORFAIT';
	END	IF;
	END;
$$ LANGUAGE 'plpgsql';



--***VIREMENT PERIODIQUE***
CREATE OR REPLACE FUNCTION virement_periodique(somme numeric(20,2), em varchar(23), iban_rec varchar(27), bic_rec varchar(11), debut date, fin date, periode varchar(13), prix numeric(20,2)) RETURNS VOID
AS $$
	DECLARE 
	id_emmetteur integer;
	id_recepteur integer;
	compte_rec varchar(23);
	ib boolean;
	argent numeric(20,2);
	BEGIN 
	
	SELECT id_client INTO id_emmetteur FROM titulaire WHERE id_compte=em;
	SELECT id_client INTO id_recepteur FROM titulaire natural join compte WHERE iban=iban_rec AND bic=bic_rec;

	--test interdit bancaire
	SELECT gele, solde INTO ib, argent FROM compte WHERE id_compte=em;
	IF ((ib='t' AND (argent-somme)>=0 ) or ib='f' ) THEN--le client n'est pas interdit bancaire ou il l'est mais a suffisamment de provisions sur le compte
		--l'emetteur du virement est aussi le recepteur alors le prix du virement est gratuit
		IF id_recepteur=id_emmetteur THEN prix:=0; END IF;
		UPDATE compte set solde = solde - (somme + prix) WHERE id_compte=em;--le compte emetteur est debiter
		IF FOUND THEN
			UPDATE compte set solde = solde + somme WHERE bic=bic_rec AND iban=iban_rec;--le compte recepteur recoit somme
			SELECT id_compte INTO compte_rec FROM compte WHERE iban=iban_rec AND bic=bic_rec;
			--une operation vient d etre effectuee on rempli virement et releve
			INSERT INTO virement (date_debut, date_fin, periodicite, montant, emetteur, recepteur) VALUES (debut, fin, periode , somme, em, compte_rec);
 			INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (debut, 'virement', -somme, em); 
			INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (debut, 'virement', somme, compte_rec);
		END IF;

	ELSE RAISE NOTICE 'INTERDIT BANCAIRE: VIREMENT IMPOSSIBLE PAR MANQUE DE PROVISIONS';
	END IF;
	END;
$$ LANGUAGE 'plpgsql';



--*** MODIFICATION DU SOLDE **** 
CREATE OR REPLACE FUNCTION verif_retrait() RETURNS TRIGGER AS $$
	DECLARE
	idcl integer;
	decouvert numeric(20,2);
	aujourdhui date;
	manda boolean;
	resp boolean;--enregistre la valeur de reponsable dans la table titulaire
	existeResp boolean;--variable qui enregistre s'il existe des responsables pour le compte où s'effectue la modification
    BEGIN

	SELECT d INTO aujourdhui FROM calendrier;   
		
    --solde negatIF
	SELECT decouvert_autorise INTO decouvert FROM compte, type_compte WHERE compte.id_compte=new.id_compte AND compte.num_type=type_compte.num_type ;
	IF new.solde < 0 AND new.solde >=decouvert THEN 
		RAISE NOTICE 'ATTENTION, LE COMPTE % EST A DECOUVERT DE % EUROS', new.id_compte,  new.solde;
		--forfait decouvert si pas deja abonné
		IF old.solde >= 0 THEN 
			INSERT INTO attente_forfait (d_prevue, type, id_compte) VALUES (aujourdhui+integer'1', 'forfait decouvert', new.id_compte);
			RETURN null;
		END IF;
	END IF;
		
	--INTERDIT BANCAIRE
	IF (new.solde < decouvert AND new.gele = 'f' AND new.tolerance ='f') THEN
		RAISE NOTICE 'VOUS AVEZ DEPASSE LE DECOUVERT AUTORISE';
		existeResp:='f';
		FOR idcl, resp in SELECT id_client, responsable FROM titulaire WHERE titulaire.id_compte=old.id_compte
		LOOP
			IF resp='t' THEN -- le/les responsables deviennent interdit bancaire
				existeResp:='t';
				PERFORM IB(idcl, new.id_banque, 'Retrait trop important');
				RAISE NOTICE 'le client % est interdit bancaire!', idCl;
			END IF;	
		END LOOP;
		IF(existeResp='f') THEN --sil ny a aucun responsable du compte, tous les titulaires seront interdit bancaire
			FOR idCl, manda in SELECT id_client, mandataire FROM titulaire WHERE titulaire.id_compte=old.id_compte
		  	LOOP
			IF manda='f' THEN
				PERFORM IB(idcl, new.id_banque, 'Retrait trop important');
				RAISE NOTICE 'le client % est interdit bancaire!', idCl;
			END IF;
			END LOOP;
		END IF;

		INSERT INTO attente_forfait (d_prevue, type, id_compte) VALUES (aujourdhui + integer '1', 'forfait decouvert', new.id_compte);
		RETURN null;
	END IF;
		
    RETURN null;
    END;
$$LANGUAGE 'plpgsql';


DROP TRIGGER IF EXISTS trig_retrait ON compte;
CREATE TRIGGER trig_retrait
       AFTER UPDATE
       ON compte
       FOR EACH ROW
       EXECUTE PROCEDURE verif_retrait();
	 

--***RETRAIT****
CREATE OR REPLACE FUNCTION retrait(ccp varchar(23), somme numeric(20,2)) RETURNS VOID
AS $$
	DECLARE
	ib boolean;
	argent numeric(20,2);
	aujourdhui date;
	et_ou varchar;

	BEGIN
	SELECT d INTO aujourdhui FROM calendrier;
	
	--test interdit bancaire
	SELECT gele, solde INTO ib, argent FROM compte WHERE id_compte=ccp;
	IF ((ib='t' AND (argent-somme)>=0 ) or ib='f' ) THEN--le client n'est pas interdit bancaire ou il l'est mais a suffisamment de provisions sur le compte
		UPDATE compte set solde = solde - somme WHERE id_compte=ccp;
		IF FOUND THEN
			SELECT etou INTO et_ou FROM compte WHERE id_compte=ccp;
			IF(et_ou='et') THEN RAISE NOTICE'SIGNATURE DE TOUT LES TITULAIRES SVP';
			ELSE RAISE NOTICE'VOTRE SIGNATURE SVP'; END IF;

			INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'retrait', -somme, ccp); 
			RAISE NOTICE 'RETRAIT EFFECTUE';
		END IF;

	ELSE RAISE NOTICE 'INTERDIT BANCAIRE: RETRAIT IMPOSSIBLE PAR MANQUE DE PROVISIONS';
	END IF;
	END;
$$ LANGUAGE 'plpgsql';


--***DEPOT LIQUIDE***
CREATE OR REPLACE FUNCTION depot_liquide(ccp varchar(23), somme numeric(20,2)) RETURNS INTEGER
AS $$
	DECLARE
	aujourdhui date;
	et_ou varchar;
	BEGIN
		SELECT d INTO aujourdhui FROM calendrier;
		UPDATE compte set solde = solde + somme WHERE id_compte=ccp;
		IF FOUND THEN
			SELECT etou INTO et_ou FROM compte WHERE id_compte=ccp;
			IF(et_ou='et') THEN RAISE NOTICE'SIGNATURE DE TOUT LES TITULAIRES SVP';
			ELSE RAISE NOTICE'VOTRE SIGNATURE SVP'; END IF;
			INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'depot liquide', somme, ccp);
			RETURN 1;
		ELSE RETURN 0; 
		END IF;
	END;
$$ LANGUAGE 'plpgsql';


--***DEPOT CHEQUE****
CREATE OR REPLACE FUNCTION depot_cheque(ccp varchar(23), somme numeric(20,2), compte_emetteur varchar(23)) RETURNS INTEGER
AS $$
	DECLARE
	gel boolean;
	aujourdhui date;
	et_ou varchar;
	BEGIN
		SELECT d INTO aujourdhui FROM calendrier;
		--on verifie que le compte emetteur n est pas gele, un interdit bancaire n'ayant pas le droit d'emettre de cheques
		SELECT gele INTO gel FROM compte WHERE id_compte=compte_emetteur;
		IF gel='f' THEN
			UPDATE compte set solde = solde - somme WHERE id_compte=compte_emetteur;
			IF FOUND THEN
				UPDATE compte set solde = solde + somme WHERE id_compte=ccp;
				SELECT etou INTO et_ou FROM compte WHERE id_compte=compte_emetteur;
				IF(et_ou='et') THEN RAISE NOTICE'SIGNATURE DE TOUT LES TITULAIRES SVP';
				ELSE RAISE NOTICE'VOTRE SIGNATURE SVP'; END IF;
				--operation effectuee on insere ce qu'il faut dans releve
				INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'depot cheque', somme, ccp); 
				INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'emission cheque', -somme, compte_emetteur);
				RETURN 1;
			END IF;
		ELSE RAISE NOTICE 'EMETTEUR DU CHEQUE INTERDIT BANCAIRE, LE CHEQUE NE SERA PAS ENCAISSE';
		RETURN 0;
		END IF;
	END;
$$ LANGUAGE 'plpgsql';



--***TOLERANCE****
CREATE OR REPLACE FUNCTION tolerance( ccp varchar(23), cl integer) RETURNS VOID
AS $$
	DECLARE 
	aujourdhui date;
	d_fin date;
	idCompte varchar(23);
	BEGIN

	SELECT d into aujourdhui FROM calendrier;
	SELECT date_regularisation into d_fin  FROM interdit_bancaire WHERE id_client = cl;
	IF (found and d_fin > aujourdhui) then
		FOR idCompte IN SELECT id_compte FROM titulaire WHERE id_client=cl
		LOOP
			UPDATE compte SET gele='f', tolerance='t' WHERE id_compte=idCompte;
			IF found then
		 		raise notice 'Compte % nest plus gele', idCompte;
			END IF;
			END LOOP;
		UPDATE interdit_bancaire SET date_regularisation= aujourdhui WHERE id_client = cl;
		IF found THEN
			raise notice 'Le client % nest plus interdit bancaire', cl; 
		END IF;
		INSERT INTO attente_forfait(d_prevue, type, id_compte) VALUES (aujourdhui+integer'1', 'forfait agio', ccp);
	ELSE
		raise notice 'Vous n etes pas interdit bancaire !';
	END IF;
	END;
$$LANGUAGE 'plpgsql';


--****releve general****
CREATE OR REPLACE FUNCTION releve_general(d date)RETURNS TABLE (date_operation date, nom_operation varchar(20),montant numeric(20,2), id_compte varchar(23))
AS $$
	BEGIN
		RETURN query SELECT releve.date_operation, releve.nom_operation, releve.montant, releve.id_compte FROM releve WHERE (releve.date_operation>= d-interval'1 month') order by releve.date_operation;
		RETURN;
	END;
$$ LANGUAGE 'plpgsql';

--****releve personnel****
CREATE OR REPLACE FUNCTION releve_personnel(d date, idCompte varchar(23)) RETURNS TABLE (date_operation date, nom_operation varchar(20),montant numeric(20,2),  id_compte varchar(23))
AS $$
	BEGIN
		RETURN query SELECT releve.date_operation, releve.nom_operation, releve.montant, releve.id_compte FROM releve WHERE (releve.date_operation >= d) AND releve.id_compte=idCompte order by releve.date_operation;
	END;
$$ LANGUAGE 'plpgsql';


--****DATE*****
CREATE OR REPLACE FUNCTION verif_date() RETURNS TRIGGER AS $$
	DECLARE
	aujourdhui date;

	--curseur
	curseur refcursor;--curseur permettant la lecture du releve general
	result record;

	--pour attente_forfait
	idAtt integer;
	dPrevue date;
	typeOperation varchar;
	monCompte varchar(23);
	monCompte2 varchar(23);
	min_rem numeric(20,2);
	taux_rem numeric(20,2);
	periodicite varchar(9);
	forfaitVirement numeric(20,2);
	forfait numeric(20,2);
	ib boolean;
	soldeCompte numeric(20,2);
	decouvert numeric(20,2);
	idbanque integer;
	typecarte integer;

	--pour attente_virement
	idAttente integer;
	date_attente date;
	date_fin date;
	montant numeric(20,2); 
	compteEmetteur varchar(23);
	iban varchar;
	bic varchar; 
	periode varchar;
	prixV numeric(20,2);

	--pour differe
	idJour integer;
	montantDif numeric(20,2);

	--pour date_fin titulaire
	idDiff integer;
	dateFin date;
	idClient integer;
	manda boolean;
	idCompte varchar(23);
	day integer;

    BEGIN
		SELECT d INTO aujourdhui FROM calendrier;
	
		--recherche des elts contenus dans attente_forfait
		FOR idAtt, dPrevue, typeOperation, monCompte IN SELECT id_attenteforfait, attente_forfait.d_prevue, attente_forfait.type, attente_forfait.id_compte FROM attente_forfait
		LOOP
			IF (dPrevue<=aujourdhui) THEN
				--affichage du releve general pour le banquier
				IF typeOperation='releve'  AND current_user = 'hirsch' THEN
					RAISE NOTICE'releve du % .', dPrevue;
					RAISE NOTICE 'DATE OPERATION|NOM|MONTANT|COMPTE';
					OPEN curseur FOR SELECT * FROM releve_general(dPrevue);
					LOOP
						FETCH curseur INTO result ;
						EXIT when NOT FOUND;
						RAISE NOTICE '%', result;
					END LOOP;
					CLOSE curseur; 
					UPDATE attente_forfait set d_prevue=dPrevue+interval'1 month' WHERE id_attenteforfait=idAtt;
				END IF;

				--remuneration pour chaque compte qui valide les conditions requises pour etre remunere
				IF typeOperation='remuneration1' THEN
					FOR soldeCompte, min_rem, periodicite, taux_rem, monCompte2 IN
					SELECT compte.solde, type_compte.min_remuneration, type_compte.periode, type_compte.taux_remuneration, compte.id_compte FROM compte natural join type_compte
					LOOP
						--on verifie la periodicite pour remunerer au bon moment
						IF (soldeCompte>=min_rem AND periodicite='quotidien') THEN
							UPDATE attente_forfait set d_prevue=dPrevue+integer '1' WHERE id_attenteforfait=idAtt;
							UPDATE compte set solde=solde+ (solde* (taux_rem/100)) WHERE id_compte=monCompte2;
						ELSE UPDATE attente_forfait set d_prevue=dPrevue+integer '1'WHERE id_attenteforfait=idAtt;
						END IF;
					END LOOP;
				END IF;

				IF typeOperation='remuneration2' THEN
					FOR soldeCompte, min_rem, periodicite, taux_rem, monCompte2 IN
					SELECT compte.solde, type_compte.min_remuneration, type_compte.periode, type_compte.taux_remuneration, compte.id_compte FROM compte natural join type_compte
					LOOP
						IF (soldeCompte>=min_rem AND periodicite='quinzaine') THEN
							UPDATE attente_forfait set d_prevue=dPrevue+integer '14'  WHERE id_attenteforfait=idAtt;
							UPDATE compte set solde=solde+ (solde* (taux_rem/100)) WHERE id_compte=monCompte2;
						ELSE UPDATE attente_forfait set d_prevue=dPrevue+integer '14'WHERE id_attenteforfait=idAtt;
						END IF;
					END LOOP;
				END IF;

				--paiement du forfait decouvert pour les comptes specifies
				IF typeOperation='forfait decouvert' THEN
					SELECT compte.solde, type_compte.decouvert_autorise, compte.gele INTO soldeCompte, decouvert, ib FROM compte natural join type_compte WHERE id_compte=monCompte;
					IF (ib = 'f' AND soldeCompte < 0 AND soldeCompte >= decouvert) THEN
						UPDATE attente_forfait set d_prevue=dPrevue+integer '1' WHERE id_attenteforfait=idAtt;
						UPDATE compte set solde=solde + (solde* 0.001) WHERE id_compte=monCompte;
					ELSEIF (ib ='t' AND soldeCompte < 0) THEN
						UPDATE attente_forfait set d_prevue=dPrevue+integer '1' WHERE id_attenteforfait=idAtt;
						UPDATE compte set solde=solde + (solde* 0.001) WHERE id_compte=monCompte;
					ELSE
						--le compte nest plus a decouvert et ne paiera donc pas de forfait decouvert la prochaine fois
						DELETE FROM attente_forfait WHERE id_attenteforfait=idAtt;
					END IF;
				END IF;

				--meme idee que pour forfait decouvert 
				IF typeOperation='forfait agio' THEN
				SELECT compte.solde, type_compte.decouvert_autorise , compte.gele INTO soldeCompte, decouvert, ib FROM compte natural join type_compte WHERE id_compte=monCompte;
					IF (ib = 'f' AND soldeCompte < decouvert) THEN
						UPDATE attente_forfait set d_prevue=dPrevue+integer '1' WHERE id_attenteforfait=idAtt;
						UPDATE compte set solde=solde + (solde* 0.002) WHERE id_compte=monCompte;
					ELSE
						DELETE FROM attente_forfait WHERE id_attenteforfait=idAtt;
						UPDATE compte set tolerance ='f' WHERE id_compte = monCompte;
					END IF;
				END IF;
			
				--forfait paye par tous les clients
				IF typeOperation='forfait virement' THEN
					FOR ib, forfaitVirement, monCompte2, soldeCompte in
					SELECT compte.gele, banque.forfait_virement, compte.id_compte, compte.solde FROM compte, banque WHERE compte.id_banque = banque.id_banque
					LOOP
						UPDATE attente_forfait set d_prevue=dPrevue+interval '1 month' WHERE id_attenteforfait=idAtt;
						SELECT gele INTO ib FROM compte WHERE id_compte=monCompte2;
						IF ib='f' THEN
							--client non interdit bancaire pouvant payer 
							UPDATE compte set solde=solde - forfaitVirement WHERE id_compte=monCompte2;
							INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (dPrevue, 'forfait virement', (0-forfaitVirement), monCompte2);
						ELSIF (ib='t' AND  soldeCompte-forfaitVirement >= 0) THEN
							--client interdit bancaire mais avec suffisamment de provisions sur son compte
							UPDATE compte set solde=solde - forfaitVirement WHERE id_compte=monCompte2;
							INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (dPrevue, 'forfait virement', (0-forfaitVirement), monCompte2);
						ELSE RAISE NOTICE 'INTERDIT BANCAIRE: PAIEMENT forfait VIREMENT IMPOSSIBLE PAR MANQUE DE PROVISIONS VOUS NE POURREZ PLUS EFFECTUER DE VIREMENT';--client interdit bancaire ne pouvant pas payer, il ne pourra pas faire de virement ce mois ci
						END IF;
					END LOOP;	
				END IF;
			

				--paiement des differents forfaits cartes pour les comptes specifies, en cas de paiement impossible on ajoute ce forfait dans la table differe pour que le client paye plus tard, le prix du forfait varie selon le type de carte et la banque
				IF typeOperation='forfait retrait' THEN
					SELECT compte.gele, banque.forfait_carte_retrait, compte.solde INTO ib, forfait, soldeCompte FROM compte, banque WHERE compte.id_banque = banque.id_banque AND id_compte=monCompte;
					UPDATE attente_forfait set d_prevue=dPrevue+interval '1 month' WHERE id_attenteforfait=idAtt;
					SELECT gele INTO ib FROM compte WHERE id_compte=monCompte;
					IF ib='t' AND  soldeCompte-forfait <= 0 THEN
						RAISE NOTICE 'INTERDIT BANCAIRE: PAIEMENT forfait RETRAIT IMPOSSIBLE PAR MANQUE DE PROVISIONS, PAIEMENT REPORTE';
						INSERT INTO differe ( type, montant, id_compte) VALUES ('forfait carte', forfait, monCompte);
					ELSE
						UPDATE compte set solde=solde - forfait WHERE id_compte=monCompte;
						INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (dPrevue, 'forfait carte', (0-forfait), monCompte);
					END IF;
				END IF;

				IF typeOperation='forfait national immediat' THEN
					SELECT compte.gele, banque.forfait_carte_pni, compte.solde INTO ib, forfait, soldeCompte FROM compte, banque WHERE compte.id_banque = banque.id_banque AND id_compte=monCompte;
					UPDATE attente_forfait set d_prevue=dPrevue+interval '1 month' WHERE id_attenteforfait=idAtt;
					SELECT gele INTO ib FROM compte WHERE id_compte=monCompte;
					IF ib='t' AND  soldeCompte-forfait <= 0 THEN
						RAISE NOTICE 'INTERDIT BANCAIRE: PAIEMENT forfait CARTE NATIONAL IMMEDIAT IMPOSSIBLE PAR MANQUE DE PROVISIONS, PAIEMENT REPORTE';
						INSERT INTO differe ( type, montant, id_compte) VALUES ('forfait carte', forfait, monCompte);
					ELSE
						UPDATE compte set solde=solde - forfait WHERE id_compte=monCompte;
						INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (dPrevue, 'forfait carte', (0-forfait), monCompte);
					END IF;	
				END IF;

				IF typeOperation='forfait national differe' THEN
					SELECT compte.gele, banque.forfait_carte_pnd, compte.solde INTO ib, forfait, soldeCompte FROM compte, banque WHERE compte.id_banque = banque.id_banque AND id_compte=monCompte;
					UPDATE attente_forfait set d_prevue=dPrevue+interval '1 month' WHERE id_attenteforfait=idAtt;
					SELECT gele INTO ib FROM compte WHERE id_compte=monCompte;
					IF ib='t' AND  soldeCompte-forfait <= 0 THEN
						RAISE NOTICE 'INTERDIT BANCAIRE: PAIEMENT forfait CARTE NATIONAL differe IMPOSSIBLE PAR MANQUE DE PROVISIONS, PAIEMENT REPORTE';
						INSERT INTO differe (type, montant, id_compte) VALUES ( 'forfait carte', forfait, monCompte);
					ELSE
						UPDATE compte set solde=solde - forfait WHERE id_compte=monCompte;
						INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (dPrevue, 'forfait carte', (0-forfait), monCompte);
					END IF;
				END IF;

				IF typeOperation='forfait international immediat' THEN
					SELECT compte.gele, banque.forfait_carte_pii, compte.solde INTO ib, forfait, soldeCompte FROM compte, banque WHERE compte.id_banque = banque.id_banque AND id_compte=monCompte;
					UPDATE attente_forfait set d_prevue=dPrevue+interval '1 month' WHERE id_attenteforfait=idAtt;
					SELECT gele INTO ib FROM compte WHERE id_compte=monCompte;
					IF ib='t' AND  soldeCompte-forfait <= 0 THEN
						RAISE NOTICE 'INTERDIT BANCAIRE: PAIEMENT forfait CARTE INTERNATIONALE IMMEDIAT IMPOSSIBLE PAR MANQUE DE PROVISIONS, PAIEMENT REPORTE';
						raise NOTICE'% f', forfait;
						INSERT INTO differe ( type, montant, id_compte) VALUES ( 'forfait carte', forfait, monCompte);
					ELSE
						UPDATE compte set solde=solde - forfait WHERE id_compte=monCompte;
						INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (dPrevue, 'forfait carte', (0-forfait), monCompte);
					END IF;
				END IF;

				IF typeOperation='forfait international differe' THEN
					SELECT compte.gele, banque.forfait_carte_pid, compte.solde INTO ib, forfait, soldeCompte FROM compte, banque WHERE compte.id_banque = banque.id_banque AND id_compte=monCompte;
					UPDATE attente_forfait set d_prevue=dPrevue+interval '1 month' WHERE id_attenteforfait=idAtt;
					SELECT gele INTO ib FROM compte WHERE id_compte=monCompte;
					IF ib='t' AND  soldeCompte-forfait <= 0 THEN
						RAISE NOTICE 'INTERDIT BANCAIRE: PAIEMENT forfait CARTE INTERNATIONALE differe IMPOSSIBLE PAR MANQUE DE PROVISIONS, PAIEMENT REPORTE';
						INSERT INTO differe ( type, montant, id_compte) VALUES ( 'forfait carte', forfait, monCompte);
					ELSE
						UPDATE compte set solde=solde - forfait WHERE id_compte=monCompte;
						INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (dPrevue, 'forfait carte', (0-forfait), monCompte);
					END IF;	
				END IF;

				IF typeOperation='forfait gold' THEN
					SELECT compte.gele, banque.forfait_carte_gold, compte.solde INTO ib, forfait, soldeCompte FROM compte, banque WHERE compte.id_banque = banque.id_banque AND id_compte=monCompte;					UPDATE attente_forfait set d_prevue=dPrevue+interval '1 month' WHERE id_attenteforfait=idAtt;
					SELECT gele INTO ib FROM compte WHERE id_compte=monCompte;
					IF ib='t' AND  soldeCompte-forfait <= 0 THEN
						RAISE NOTICE 'INTERDIT BANCAIRE: PAIEMENT forfait GOLD IMPOSSIBLE PAR MANQUE DE PROVISIONS, PAIEMENT REPORTE';
						INSERT INTO differe ( type, montant, id_compte) VALUES ('forfait carte', forfait, monCompte);
					ELSE
						UPDATE compte set solde=solde - forfait WHERE id_compte=monCompte;
						INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (dPrevue, 'forfait carte', (0-forfait), monCompte);
					END IF;	
				END IF;

			END IF;
		END LOOP;

		--remise des plafond de semaine a zero chaque lundi
		SELECT EXTRACT(DOW FROM aujourdhui) into idJour;
		IF idJour=0 THEN UPDATE compte set plafond_semaine=0;
		END IF;
	
		--les virements
		FOR idAttente, date_attente, date_fin, montant, compteEmetteur, iban, bic, periode, prixV in
		SELECT id_attenteVirement, attente_virement.d_prevue, d_fin, somme, em, iban_rec, bic_rec, attente_virement.periodicite, prix_virement FROM attente_virement
		LOOP
			IF (date_attente<=aujourdhui) THEN
				IF (date_attente=date_fin) THEN --virement unique
					PERFORM virement_unique(montant,compteEmetteur , iban , bic , date_attente);
					DELETE FROM attente_virement WHERE id_attenteVirement=idAttente;
				ELSE --virement periodique
					PERFORM virement_periodique(montant, compteEmetteur, iban, bic, date_attente, date_fin, periode , prixV);
					IF periode='quinzaine' THEN 
						UPDATE attente_virement set d_prevue= (date_attente+ integer '14'), prix_virement = 0.25  WHERE id_attenteVirement=idAttente; 
					END IF; 
					IF periode= 'mensuelle' THEN
						UPDATE attente_virement set d_prevue= (date_attente+ interval '1 month'), prix_virement = 0.25 WHERE id_attenteVirement=idAttente; 
					END IF;
					IF periode='trimestrielle' THEN 
						UPDATE attente_virement set d_prevue= (date_attente+ interval '3 months'), prix_virement = 0.25 WHERE id_attenteVirement=idAttente; 
					END IF;
					IF periode='semestrielle' THEN 
						UPDATE attente_virement set d_prevue= (date_attente+ interval '6 months'), prix_virement = 0.25 WHERE id_attenteVirement=idAttente; 
					END IF;
					IF periode='annuelle' THEN 
						UPDATE attente_virement set d_prevue= (date_attente+ interval '1 year'), prix_virement = 0.25 WHERE id_attenteVirement=idAttente; 
					END IF;
				END IF;
			END IF;
		END LOOP;	

		--le differe, si un client ne peut pas payer son differe ce mois ci on reporte au mois prochain avec une penalite
		SELECT extract ( DAY FROM aujourdhui) INTO day;
		IF day = 28 THEN
			FOR idDiff,  typeOperation, montantDif, monCompte IN
			SELECT id_differe,  differe.type, differe.montant, differe.id_compte FROM differe
			LOOP
			
		  		IF typeOperation = 'achat' THEN
					SELECT compte.solde, compte.gele INTO soldeCompte, ib FROM compte natural join type_compte WHERE id_compte=monCompte;
					IF ib = 't' AND soldeCompte - montantDif < 0 THEN
				    	RAISE NOTICE 'INTERDIT BANCAIRE: IMPOSSIBLE D EFFECTUER L OPERATION PAR MANQUE DE PROVISIONS, differe REPORTE AU MOIS PROCHAIN AVEC 1 EURO DE PENALITE';
				    	UPDATE differe set montant = (differe.montant + 1) WHERE id_differe = idDiff;
					ELSE 
				   		UPDATE compte set solde = solde - montantDif WHERE id_compte = monCompte;
				    	INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'achat differe', (0-montantDif), monCompte);
				    	DELETE FROM  differe WHERE id_differe = idDiff;
				    	RAISE NOTICE 'PAIEMENT DES ACHATS differeS';
					END IF;
		   		ELSE
					SELECT compte.solde, compte.gele, compte.id_carte, compte.id_banque INTO soldeCompte, ib, typecarte, idbanque FROM compte natural join type_compte WHERE id_compte=monCompte;
				    IF ib = 't' AND soldeCompte - montant < 0 THEN
				    	RAISE NOTICE 'INTERDIT BANCAIRE: IMPOSSIBLE D EFFECTUER L OPERATION PAR MANQUE DE PROVISIONS, forfait REPORTE AU MOIS PROCHAIN';
				    	UPDATE differe set  montant = (differe.montant+0.5)+(differe.montant) WHERE id_differe = idDiff;
				    ELSE 
				      	UPDATE compte set solde = solde - montantDif WHERE id_compte = monCompte;
				      	INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'achat differe', (0-montantDif), monCompte);
				      	DELETE FROM  differe WHERE id_differe = idDiff;
				      	IF(typecarte=1 or typecarte=2) THEN
				      		SELECT banque.forfait_carte_retrait INTO forfait FROM banque WHERE banque.id_banque=idbanque;
				      	END IF;

				      	IF(typecarte=3) THEN
				      		SELECT banque.forfait_carte_pni INTO forfait FROM banque WHERE banque.id_banque=idbanque;
				      	END IF;

				      	IF(typecarte=4) THEN
				      		SELECT banque.forfait_carte_pnd INTO forfait FROM banque WHERE banque.id_banque=idbanque;
				      	END IF;

				      	IF(typecarte=5) THEN
				      		SELECT banque.forfait_carte_pii INTO forfait FROM banque WHERE banque.id_banque=idbanque;
				      	END IF;

				      	IF(typecarte=6)THEN
				      		SELECT banque.forfait_carte_pid INTO forfait FROM banque WHERE banque.id_banque=idbanque;
				      	END IF;

 					  	IF(typecarte=7) THEN
				     	 	SELECT banque.forfait_carte_gold INTO forfait FROM banque WHERE banque.id_banque=idbanque;
				      	END IF;

				      	INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'forfait carte', (0-forfait), monCompte);
				      	RAISE NOTICE 'PAIEMENT DU forfait differe';
				    END IF;
		   		END IF;
		   	END LOOP;
		END IF;
 		

 		--Date de fin des mandataire
		FOR idClient , dateFin, manda, idCompte IN 
		SELECT titulaire.id_client, titulaire.date_fin, titulaire.mandataire, titulaire.id_compte FROM titulaire
		LOOP
			IF (manda='t' and dateFin = aujourdhui) THEN 
				DELETE FROM titulaire where id_client=idClient and id_compte=idCompte;
			END IF;
		END LOOP;

		--Date de fin des interdits bancaires
		FOR  dateFin, idCompte IN 
		SELECT  interdit_bancaire.date_regularisation, titulaire.id_compte FROM interdit_bancaire, titulaire where titulaire.id_client=interdit_bancaire.id_client
		LOOP
			IF (dateFin = aujourdhui) THEN 
				UPDATE compte set gele='f' where id_compte=idCompte;
			END IF;
		END LOOP;
	RETURN new;
    END;
$$LANGUAGE 'plpgsql';


DROP TRIGGER IF EXISTS trig_date ON calendrier;
CREATE TRIGGER trig_date
       AFTER UPDATE
       ON calendrier
       FOR EACH ROW
       EXECUTE PROCEDURE verif_date();
	 

---***retrait carte****
CREATE OR REPLACE FUNCTION retrait_carte(ccp varchar(23), somme numeric(20,2), idbanque integer)RETURNS VOID --retrait ds meme banque
AS $$
	DECLARE
	nomType varchar;
	typeAuto varchar;
	idb integer;
	idbanque integer;
	plafondOp numeric(20,2);--plafond par operation de la banque
	plafondWeek numeric(20,2);--plafond par semaine de la banque
	retraitWeek numeric(20,2);--retrait effectue depuis le debut de la semaine
	retraitMin numeric(20,2);--retrait par semaine maximum autorise par les parents pour un mineur	
	aujourdhui date;
	soldeCompte numeric(20,2);
	BEGIN
		SELECT d INTO aujourdhui FROM calendrier;
		SELECT compte.id_banque, plafond_operation, banque.plafond_semaine, compte.plafond_semaine, plafond_mineur INTO idb, plafondOp, plafondWeek, retraitWeek, retraitMin FROM banque,compte WHERE banque.id_banque = compte.id_banque AND compte.id_compte = ccp; 
		SELECT solde, type_carte, type_autorisation INTO soldeCompte, nomType, typeAuto FROM compte natural join type_carte WHERE compte.id_compte = ccp AND type_carte.id_carte = compte.id_carte ;
		IF FOUND THEN
			--carte de retrait a autorisation systematique
	   		IF (nomType = 'retrait' AND typeAuto = 'systematique') THEN
	      		IF (soldeCompte - somme < 0) THEN RAISE NOTICE 'IMPOSSIBLE D EFFECTUER L OPERATION, VOUS DISPOSERIEZ D UN SOLDE NEGATIF';
	      		ELSEIF (idb = idbanque) THEN --retrait effectue dans la banque du client 
				--on verifie que la somme que veut retirer le client n est pas superieure au plafond autorise par la banque pour une operation
	      	    	IF (somme > plafondOp) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LA BANQUE';
				--on verifie que le client ne depasse pas le plafond_semaine avec ce retrait				
		     		ELSEIF (retraitWeek + somme > plafondWeek) THEN  RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR SEMAINE';
				--pour les mineurs on verifie qu'il ne depasse pas le plafond autorise par les parents 
		     		ELSEIF (retraitMin != 0 AND retraitWeek + somme > retraitMin ) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LES PARENTS';
		     		ELSE 
				--l operation peut etre effectuee
		     			UPDATE compte set solde = solde - somme, plafond_semaine = plafond_semaine + somme WHERE id_compte = ccp;
						INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'retrait distributeur', -somme, ccp);
		      			RAISE NOTICE'retrait effectue';
		     		END IF;
	      		ELSE--retrait effectue dans une autre banque, changement sur les plafonds mais meme idee pour le reste
		    		IF somme > (plafondOp-100) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LA BANQUE';
		    		ELSEIF retraitWeek + somme > (plafondWeek-500) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR SEMAINE';
		    		ELSEIF ((retraitMin != 0) AND ((retraitWeek + somme) > retraitMin)) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LES PARENTS';
		    		ELSE
		    	 		RAISE NOTICE'retrait effectue';
		     			UPDATE compte set solde = solde - (somme), plafond_semaine = plafond_semaine + (somme) WHERE id_compte = ccp;
		     			INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'retrait distributeur', -somme, ccp);
		     		END IF;
		    	END IF; 
			--carte de retrait a autorisation normale, memes verifications que precedemment sauf pour le solde > 0
           	ELSEIF (nomType = 'retrait' AND typeAuto = 'normal') THEN
	     		IF (idb = idbanque) THEN 
	      	     	IF (somme > plafondOp) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LA BANQUE';
		     		ELSEIF (retraitWeek + somme > plafondWeek) THEN  RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR SEMAINE';
		     		ELSEIF (retraitMin != 0 AND retraitWeek + somme > retraitMin ) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LES PARENTS';
		     		ELSE 
		      			RAISE NOTICE'retrait effectue';
		     			UPDATE compte set solde = solde - somme, plafond_semaine = plafond_semaine + somme WHERE id_compte = ccp;
						INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'retrait distributeur', -somme, ccp);
		     		END IF;
	      		ELSE
		    		IF somme > (plafondOp-100) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LA BANQUE';
		    		ELSEIF retraitWeek + somme > (plafondWeek-500) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR SEMAINE';
		    		ELSEIF (retraitMin != 0 AND retraitWeek + somme > retraitMin) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LES PARENTS';
		    		ELSE
		     			RAISE NOTICE'retrait effectue';
		     			UPDATE compte set solde = solde - somme, plafond_semaine = plafond_semaine + somme WHERE id_compte = ccp;
		     			INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'retrait distributeur', -somme, ccp);
		    		END IF; 
	     		END IF; 
			--carte de paiement de type gold, memes verifications que precedemment sauf pour les mineurs qui ne peuvent pas avoir ce type de carte et l'id de banque où on retire de l argent n a plus d importance
	   		ELSEIF nomType = 'gold' THEN
	       		IF somme > (plafondOp +1000) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LA BANQUE';
		   		ELSEIF retraitWeek + somme > (plafondWeek+2000) THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR SEMAINE';
		   		ELSE
		    		RAISE NOTICE'retrait effectue';
		       		UPDATE compte set solde = solde - somme, plafond_semaine = plafond_semaine + somme WHERE id_compte = ccp;
		       		INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'retrait distributeur', -somme, ccp);
	   	   		END IF;
			--carte de paiement autre que gold, memes verifications que precedemment
	   		ELSE
		   		IF somme > plafondOp THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR LA BANQUE';
		   		ELSEIF retraitWeek + somme > plafondWeek THEN RAISE NOTICE 'DEPASSEMENT DU PLAFOND AUTORISE PAR SEMAINE';
		   		ELSE
		    		RAISE NOTICE'retrait effectue';
		     		UPDATE compte set solde = solde - somme, plafond_semaine = plafond_semaine + somme WHERE id_compte = ccp;
		     		INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'retrait distributeur', -somme, ccp);
	   	   		END IF;  	 	
	   		END IF;
		END IF;
	END;
$$ LANGUAGE 'plpgsql';


--***achat en france***
CREATE OR REPLACE FUNCTION achat_national(ccp varchar(23), montant numeric(20,2))RETURNS VOID
AS $$
	DECLARE
	nomType varchar;	
	aujourdhui date;
	soldeCompte numeric(20,2);
	gel boolean;	
	BEGIN
	SELECT d INTO aujourdhui FROM calendrier;
	SELECT type_carte, solde, gele  INTO nomType, soldeCompte, gel FROM compte natural join type_carte WHERE compte.id_compte = ccp AND type_carte.id_carte = compte.id_carte ;
	IF FOUND THEN
	   	IF (nomType = 'paiement national immediat' or nomType = 'paiement gold' or nomType='paiement international immediat') THEN
	   		IF ((gel = 't' AND soldeCompte - montant >=0) OR gel = 'f') THEN 
	      		UPDATE compte set solde = solde - montant WHERE id_compte = ccp;
	      		INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'achat national', -montant, ccp);
	   	  		RAISE NOTICE'ACHAT EFFECTUE';
	   	  	ELSE RAISE NOTICE 'VOUS ETES INTERDIT BANCAIRE ET NE DISPOSEZ PAS DES FONDS SUFFISANTS POUR EFFECTUER CET ACHAT';
	   	  	END IF;
	   	ELSIF (nomType = 'paiement national differe' or nomType='paiement international differe') THEN
			INSERT INTO differe ( type, montant, id_compte) VALUES ('achat', montant, ccp);
			RAISE NOTICE'ACHAT EFFECTUE, ET FACTURE A LA FIN DU MOIS';
		ELSE RAISE NOTICE 'VOUS NE DISPOSEZ PAS D UNE CARTE VALIDE POUR EFFECTUER CETTE OPERATION';
	   	END IF;
	END IF;
END;
$$ LANGUAGE 'plpgsql';


--**achat a letranger***
CREATE OR REPLACE FUNCTION achat_international(ccp varchar(23), montant numeric(20,2))RETURNS VOID
AS $$
	DECLARE
	nomType varchar;
	aujourdhui date;
	soldeCompte numeric(20,2);
	gel boolean;
	BEGIN
	SELECT d INTO aujourdhui FROM calendrier;
	SELECT type_carte, solde, gele  INTO nomType, soldeCompte, gel FROM compte natural join type_carte WHERE compte.id_compte = ccp AND type_carte.id_carte = compte.id_carte ;
	IF FOUND THEN
	   	IF (nomType = 'paiement international immediat' or nomType='paiement gold') THEN
	   		IF ((gel = 't' AND soldeCompte - montant >=0) OR gel = 'f') THEN 
	   			UPDATE compte set solde = solde - montant WHERE id_compte = ccp;
	   			INSERT INTO releve (date_operation, nom_operation, montant, id_compte) VALUES (aujourdhui, 'achat international', -montant, ccp);
	   			RAISE NOTICE'ACHAT EFFECTUE';
	   		ELSE RAISE NOTICE 'VOUS ETES INTERDIT BANCAIRE ET NE DISPOSEZ PAS DES FONDS SUFFISANTS POUR EFFECTUER CET ACHAT';
	   	  	END IF;
	   	ELSIF nomType = 'paiement international differe' THEN
			INSERT INTO differe ( type, montant, id_compte) VALUES ( 'achat', montant, ccp);
			RAISE NOTICE'ACHAT EFFECTUE, ET FACTURE A LA FIN DU MOIS';
		ELSE RAISE NOTICE 'VOUS NE DISPOSEZ PAS D UNE CARTE VALIDE POUR EFFECTUER CETTE OPERATION';
	   	END IF;
	END IF;
END;
$$ LANGUAGE 'plpgsql';


--**ajout titulaire***
CREATE OR REPLACE FUNCTION ajout_titulaire(ccp varchar(23), n varchar, p varchar, a integer)RETURNS VOID
AS $$
	DECLARE
	cl integer;
	aujourdhui date;
	BEGIN 
	SELECT d INTO aujourdhui FROM calendrier;
	SELECT id_client INTO cl FROM client WHERE client.nom = n AND client.prenom = p AND client.age = a; 
	--un co-titulaire doit etre un client de la banque
	IF FOUND THEN
		INSERT INTO titulaire VALUES (cl, ccp,'f', 'f', aujourdhui + interval '100 years'); 
		RAISE NOTICE '% % est un nouveau titulaire du compte!', n,p;
	ELSE RAISE NOTICE 'Attention, ce client est inconnu de notre base de donnee';
	END IF;
END;
$$ LANGUAGE 'plpgsql';


--***ajoute responsable****
CREATE OR REPLACE FUNCTION ajout_responsable(ccp varchar, n varchar, p varchar, a integer)RETURNS VOID
AS $$
	DECLARE
	cl integer;
	BEGIN
	SELECT id_client INTO cl FROM client natural join titulaire WHERE client.nom = n AND client.prenom = p AND client.age = a AND titulaire.id_compte = ccp;
	--un responsable doit etre co-titulaire du compte
	IF FOUND THEN 
		RAISE NOTICE 'Nouveau responsable ajoute';
		UPDATE titulaire set responsable = 't' WHERE titulaire.id_client = cl AND titulaire.id_compte=ccp;
	ELSE 
		RAISE NOTICE 'Vous n etes pas un co-titulaire du compte !';
	END IF; 
END;
$$ LANGUAGE 'plpgsql';


--***procuration***
CREATE OR REPLACE FUNCTION procuration(ccp varchar, n varchar, p varchar, a integer, datef date, idcl integer)RETURNS VOID
AS $$
	DECLARE
	cl integer;
	respon boolean;
	manda boolean;
	BEGIN
	SELECT responsable, mandataire INTO respon, manda FROM titulaire WHERE titulaire.id_client = idcl AND titulaire.id_compte=ccp;
		IF (respon = 't' or manda = 't') THEN
			RAISE NOTICE'% % est a present mandataire du compte % jusquau %', n,p,ccp,datef;
			SELECT id_client INTO cl FROM client WHERE client.nom = n AND client.prenom = p AND client.age = a;
			IF not found THEN RAISE NOTICE 'Attention, ce client est inconnu de notre base de donnee'; END IF;
			PERFORM id_client FROM titulaire WHERE titulaire.id_client=cl and titulaire.id_compte=ccp;
			IF found THEN
				RAISE NOTICE'Attention ce client est deja titulaire du compte';
			ELSE
				INSERT INTO titulaire VALUES (cl, ccp,'f', 't',  datef);
			END IF;
		ELSE 
			RAISE NOTICE 'Seuls les responsables et mandataires peuvent designer un autre mandataire';
		END IF;
END;
$$ LANGUAGE 'plpgsql';
