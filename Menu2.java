import java.util.*;
import java.sql.*;
import java.io.*;
public class Menu2 {

	static Connexion2 co;
	public static void main(String[] args) {
		try{
			co = new Connexion2();
			String nom, prenom, nom2, prenom2, id_cp = "", id_cp2 = "", et_ou = "ou", att, reponse2, date;
			int age, age2, reponse = 0, id_client=1, id_banque=1, id_agence=1, typec = 0, type_cp = 0,  plafMin=0,
					solde = 0, montant=0;
			boolean joint=false;
			ResultSet res;
			Scanner sc = new Scanner(System.in);
			System.out.print("\033c");
			System.out.println("\t \t Bienvenue cher client!");
			System.out.println("\nChoisissez votre banque (entrez le numero de la banque choisie)");
			res=co.choisirBanque();
			while(res != null && res.next()){
				System.out.print(res.getInt("id_banque"));
				System.out.println(" - " + res.getString("nom"));
			}
			res.close();
			id_banque=sc.nextInt();
			System.out.println("Choisissez votre agence (entrez le numero de l'agence choisie)");
			res=co.choisirAgence(id_banque);
			while(res != null && res.next()){
				System.out.print(res.getInt("id_agence"));
				System.out.println(" - " + res.getString("nom"));
			}
			id_agence=sc.nextInt();
			System.out.println("Veuillez saisir votre identifiant de compte, nom, prenom, et votre age: " +
					"(veuillez saisir 00 si vous n'etes pas encore client)");
			id_cp = sc.next();
			nom = sc.next();
			prenom = sc.next();
			age = sc.nextInt();
			res = co.verif_client(nom, prenom,age, id_cp);
			System.out.println("OK pour se connecter");
			att=sc.next();
			if(res.next()){//le client est bien dans la base
				id_client = res.getInt("id_client");//on enregistre son id pour pouvoir l'utiliser dans les appels de fonctions
				while (reponse != 17){//tant qu'on ne quitte pas
					System.out.print("\033c");
					System.out.println("\t \t MENU PRINCIPAL\n");
					System.out.println("1 - Ouverture d'un compte");
					System.out.println("2 - Fermeture du compte ");
					System.out.println("3 - Consultation du solde ");
					System.out.println("4 - Faire un virement unique ");
					System.out.println("5 - Faire un virement permanent ");
					System.out.println("6 - Faire un retrait ");
					System.out.println("7 - Deposer du liquide ");
					System.out.println("8 - Deposer un cheque ");
					System.out.println("9 - Afficher un releve personnel ");
					System.out.println("10 - Revenir demain ");
					System.out.println("11 - Revenir dans quinze jours");
					System.out.println("12 - Demande de tolerance");
					System.out.println("13 - Retrait a un distributeur");
					System.out.println("14 - Achat en France");
					System.out.println("15 - Achat a l'international");
					System.out.println("16 - Designer un mandataire");
					System.out.println("17 - Quitter ");
					reponse = sc.nextInt();
					switch(reponse){
					case 1:
					System.out.print("\033c");
					System.out.println("Choisissez votre type de compte (entrez le numero du type de compte choisi)");
					res=co.choisirCompte();
					while(res != null && res.next()){
						System.out.print(res.getInt("num_type") + " - ");
						System.out.println(res.getString("nom_type"));
					}
					type_cp = sc.nextInt();
					if(type_cp > 1){
						System.out.println("Choisissez votre type de carte (entrez le numero de carte choisi)");
						res=co.choisirCarte();
						while(res != null && res.next()){
							System.out.print(res.getInt("id_carte") + " - ");
							System.out.print(res.getString("type_autorisation") + ", ");
							System.out.println(res.getString("type_carte"));
						}
						typec = sc.nextInt();
					}
					System.out.println("Veuillez saisir le montant que vous souhaitez deposer sur votre compte");
					solde = sc.nextInt();
					if(age <18){
							System.out.println("Les parents, definissez un plafond.");
							plafMin = sc.nextInt();
					}
					System.out.println("Souhaitez vous ouvrir un compte joint ?");
					if(sc.next().equals("oui")){
						joint = true;
						System.out.println("Type du compte joint, ET ou OU");
						et_ou = sc.next();
					  	id_cp=co.new_compte(id_client, id_agence, id_banque, type_cp, solde, plafMin, typec, joint, et_ou);
						
						reponse2="";
						while(!reponse2.equals("ok")){
							System.out.println("Entrez le nom, prenom et age du cotitulaire");
							nom2 = sc.next();
							prenom2 = sc.next();
							age2 = sc.nextInt();
							co.ajout_titulaire(id_cp, nom2, prenom2, age2);
							System.out.println("Entrez \"ok\" s'il n'y a pas d'autres co_titulaires entrez \"suivant\" sinon");
							reponse2 = sc.next();
						}
						reponse2="";
						while(!(reponse2.equals("ok")) && !(reponse2.equals("non"))){
							System.out.println("Voulez-vous designer un/des responsable ? oui/non ( pour les comptes association" +
									" et entreprise cela est obligatoire) ");
							reponse2 = sc.next();
							if(reponse2.equals("oui")){
								System.out.println("Entrez le nom, prenom, et age de la personne qui sera reponsable ");
								nom2 = sc.next();
								prenom2 = sc.next();
								age2 = sc.nextInt();
								co.ajout_responsable(id_cp, nom2, prenom2, age2);
								System.out.println("Entrez \"ok\" s'il n'y a pas d'autres responsables et entrez \"suivant\" sinon");
								reponse2 = sc.next();
							}
						}
					}
					else {
						id_cp=co.new_compte(id_client, id_agence, id_banque, type_cp, solde, plafMin, typec, joint, et_ou);
						System.out.println("OK pour continuer");
						att=sc.next();
					}
					break;
					case 2:
						System.out.print("\033c");
						co.ferme_cp(id_client, id_cp);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 3:
						System.out.print("\033c");
						co.consult(id_client, id_cp);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 4:
						System.out.print("\033c");
						System.out.println("Indiquez le montant a virer");
						montant = sc.nextInt();
						System.out.println("Indiquez l'iban du compte destinataire");
						String ban_rec = sc.next();
						System.out.println("Indiquez le bic du compte destinataire");
						String bic_rec = sc.next();
						System.out.println("Indiquez la date a laquelle vous souhaitez effectuer le virement YYYY-MM-JJ");
						String d_debut = sc.next();
						co.virement_unique(montant, id_cp, ban_rec, bic_rec, d_debut);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 5:
						System.out.print("\033c");
						System.out.println("Indiquez le montant a virer");
						montant = sc.nextInt();
						System.out.println("Indiquez l'iban du compte destinataire");
						ban_rec = sc.next();
						System.out.println("Indiquez le bic du compte destinataire");
						bic_rec = sc.next();
						System.out.println("Indiquez la date a laquelle vous souhaitez effectuer le virement YYYY-MM-JJ");
						d_debut = sc.next();
						System.out.println("Indiquez la date a laquelle vous souhaitez arreter le virement periodique YYYY-MM-JJ");
						String d_fin = sc.next();
						System.out.println("Indiquez la periodicite de votre virement");
						String periode = sc.next();
						co.virement_periodique(montant, id_cp, ban_rec, bic_rec, d_debut, d_fin, periode);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 6:
						System.out.print("\033c");
						System.out.println("Indiquez la somme que vous souhaitez retirer");
						montant = sc.nextInt();
						co.retrait(id_cp, montant);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 7:
						System.out.print("\033c");
						System.out.println("Indiquez la somme a deposer");
						montant = sc.nextInt();
						co.depot_liquide(id_cp, montant);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 8:
						System.out.print("\033c");
						System.out.println("Indiquez la somme a deposer");
						montant = sc.nextInt();
						System.out.println("Indiquez le numero du compte emetteur");
						id_cp2=String.valueOf(sc.nextInt());
						co.depot_cheque(id_cp, montant, id_cp2);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 9:
						System.out.print("\033c");
						System.out.println("Indiquez la date souhaitee pour afficher le releve");
						d_debut = sc.next();
						co.releve(d_debut, id_cp);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 10:
						co.tomorrow();
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 11:
						for(int i = 0; i<14; i++){
							co.tomorrow();
						}
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 12:
						System.out.print("\033c");
						co.tolerance(id_cp, id_client);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 13:
						System.out.print("\033c");
						System.out.println("Veuillez choisir la banque d'ou vous souhaitez retirer de l'argent:");
						res = co.choisirBanque();
						while(res != null && res.next()){
							System.out.print(res.getInt("id_banque"));
							System.out.println(" - " + res.getString("nom"));
						}
						int id_banque2 = sc.nextInt();
						System.out.println("Veuillez saisir le montant a retirer");
						montant=sc.nextInt();
						co.retrait_distrib(id_cp, montant, id_banque2);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 14:
						System.out.print("\033c");
						System.out.println("Veuillez saisir le montant de vos achats:");
						montant = sc.nextInt();
						co.achat_natio(id_cp, montant);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 15:
						System.out.print("\033c");
						System.out.println("Veuillez saisir le montant de vos achats:");
						montant= sc.nextInt();
						co.achat_inter(id_cp, montant);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 16:
						System.out.print("\033c");
						System.out.println("Entrez le nom, prenom, et age de la personne qui deviendra mandataire");
						nom2 = sc.next();
						prenom2 = sc.next();
						age2 = sc.nextInt();
						date="";
						System.out.println("Entrez la date jusqu'a laquelle cette personne sera mandataire YYYY-MM-JJ");
						date=sc.next();
						co.procuration(id_cp, nom2, prenom2, age2, date, id_client);
						System.out.println("OK pour continuer");
						att=sc.next();
						break;
					case 17:
						co.close();
						System.exit(1);
						break;
					}
				}
			}
			//sinon
			//enregistrer l'id du client;
			else{
				System.out.print("\033c");
				System.out.println("Vous n'etes pas encore client ! Vous pouvez: ");
				System.out.println("1 - Devenir client");
				System.out.println("2 - Quitter");
				reponse = sc.nextInt();
				if(reponse == 1){
					co.new_client(nom, prenom, age);
					res=co.verif_client(nom,prenom, age, "null");
					if(res.next()){
						id_client = res.getInt("id_client");
					}
					System.out.println("Choisissez votre type de compte (entrez le numero du type choisi)");
					res=co.choisirCompte();
					while(res != null && res.next()){
						System.out.print(res.getInt("num_type") + " - ");
						System.out.println(res.getString("nom_type"));
					}
					type_cp = sc.nextInt();
					if(type_cp > 1){
						System.out.println("Choisissez votre type de carte (entrez le numero du type choisi)");
						res=co.choisirCarte();
						while(res != null && res.next()){
							System.out.print(res.getInt("id_carte") + " - ");
							System.out.print(res.getString("type_autorisation") + ", ");
							System.out.println(res.getString("type_carte"));
						}
						typec = sc.nextInt();
					}
					System.out.println("Veuillez saisir le montant que vous souhaitez deposer sur votre compte");
					solde = sc.nextInt();
					if(age <18){
							System.out.println("Les parents, definissez un plafond.");
							plafMin = sc.nextInt();
					}
					System.out.println("Souhaitez vous ouvrir un compte joint ?");
					if(sc.next().equals("oui")){
						joint = true;
						System.out.println("Type du compte joint, ET ou OU");
						et_ou = sc.next();
					  	id_cp=co.new_compte(id_client, id_agence, id_banque, type_cp, solde, plafMin, typec, joint, et_ou);
						reponse2="";
						while(!reponse2.equals("ok")){
							System.out.println("Entrez le nom, prenom et age du cotitulaire");
							nom2 = sc.next();
							prenom2 = sc.next();
							age2 = sc.nextInt();
							co.ajout_titulaire(id_cp, nom2, prenom2, age2);
							System.out.println("Entrez \"ok\" s'il n'y a pas d'autres co_titulaires entrez \"suivant\" sinon");
							reponse2 = sc.next();
						}
						reponse2="";
						while(!(reponse2.equals("ok")) && !(reponse2.equals("non"))){
							System.out.println("Voulez-vous designer un/des responsable ? oui/non ( pour les comptes association" +
									" et entreprise cela est obligatoire) ");
							reponse2 = sc.next();
							if(reponse2.equals("oui")){
								System.out.println("Entrez le nom, prenom, et age de la personne qui sera reponsable ");
								nom2 = sc.next();
								prenom2 = sc.next();
								age2 = sc.nextInt();
								co.ajout_responsable(id_cp, nom2, prenom2, age2);
								System.out.println("Entrez \"ok\" s'il n'y a pas d'autres responsables et entrez \"suivant\" sinon");
								reponse2 = sc.next();
							}
						}
					}
					else 	id_cp=co.new_compte(id_client, id_agence, id_banque, type_cp, solde, plafMin, typec, joint, et_ou);
				}	
				else{
					co.close();
					System.exit(1);
				}

			}
		}
		catch(SQLException e){
			e.printStackTrace();
			System.out.println("erreur");
		}
		catch(ClassNotFoundException e){
			e.printStackTrace();
		}
	}
}

