import java.util.*;
import java.sql.*;
import java.io.*;


public class Connexion2{
	Connection co;
	PreparedStatement ps;
	Statement s;
	ResultSet res;
	CallableStatement c;
	java.sql.Date d;


	public Connexion2() throws SQLException, ClassNotFoundException{
		Class.forName("org.postgresql.Driver");
		co = DriverManager.getConnection("jdbc:postgresql://localhost/base/" , "hirsch", "BD2013");
		s = co.createStatement();
		s.execute("set search_path to projet_hirsch");
	}

	public void close() throws SQLException{
		co.close();
	}

	//affichage des banques presentes dans nos tables
	public ResultSet choisirBanque() throws SQLException{
		s= co.createStatement();
		res = s.executeQuery("select id_banque, nom from banque;");
		return res;
	}
	
	//affichage des agences en fonction de la banque choisie
	public ResultSet choisirAgence(int id_banque) throws SQLException{
		ps = co.prepareStatement("select id_agence, nom from agence where agence.id_banque = ?;");
		ps.setInt(1,id_banque);
		res = ps.executeQuery();
		return res;
	}
	
	//affichage de tous les types de comptes disponibles dans nos banques
	public ResultSet choisirCompte() throws SQLException{
		s = co.createStatement();
		res = s.executeQuery("select num_type, nom_type from type_compte");
		return res;
	}
	
	//affichage de tous les types de cartes
	public ResultSet choisirCarte() throws SQLException{
		s = co.createStatement();
		res = s.executeQuery("select id_carte, type_autorisation, type_carte from type_carte;");
		return res;
	}
	
	//verifie si le client est bien present dans notre base
	public ResultSet verif_client(String nom, String prenom,int age, String id_cp) throws SQLException{
		if (id_cp.compareTo("null") == 0) {
			ps = co.prepareStatement("select id_client from client where nom = ? and prenom = ? and age= ?;");
			ps.setString(1,nom);
			ps.setString(2, prenom);
			ps.setInt(3, age);
			res = ps.executeQuery();
		
		} else {
			ps = co.prepareStatement("select id_client from client natural join compte where nom = ? and prenom = ? and age= ? and id_compte = ?;");
			ps.setString(1,nom);
			ps.setString(2, prenom);
			ps.setInt(3, age);
			ps.setString(4, id_cp);
			res = ps.executeQuery();
		}
		return res;
	}
	
	
	//appelle la fonction insert_client
	public void new_client(String nom, String prenom, int age) throws SQLException{
		c = co.prepareCall("{call insert_client(?,?,?)}");
		c.setString(1, nom);
		c.setString(2, prenom);
		c.setInt(3,age);
		c.execute();
	}

	//appelle la fonction ouverture_compte
	public String new_compte(int id_client, int id_agence, int id_banque, int type_cp, int solde, int plafMin, int typec, boolean joint, String et_ou) throws SQLException{
		//numero de compte, iban et bic choisis au hasard
		c = co.prepareCall("{? = call verif_choix(?,?,?)}");
		c.registerOutParameter(1, Types.INTEGER);
		c.setInt(2, id_client);
		c.setInt(3, type_cp);
		c.setInt(4, typec);
		c.execute();
		System.out.println(c.getWarnings());
		if(c.getInt(1) == 1){
			String cp = String.valueOf( 10000 + (int)(Math.random() * (999999999 - 10000) +1 ));
			String ban = String.valueOf( 10000 + (int)(Math.random() * (9999999 - 10000) + 1));
			String bic = String.valueOf( 100 + (int)(Math.random() * (999999 - 100) +1));
			c = co.prepareCall("{? = call ouverture_compte(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,?)}");
			c.registerOutParameter(1, Types.INTEGER);
			c.setInt(2, id_client);
			c.setInt(3, id_agence);
			c.setInt(4, id_banque);
			c.setString(5, cp);
			c.setString(6, ban);
			c.setString(7, bic);
			c.setInt(8, type_cp);
			c.setInt(9, solde);
			c.setInt(10, plafMin);
			c.setInt(11, typec);
			c.setBoolean(12, joint);
			c.setString(13, et_ou);
			c.execute();
			if(c.getInt(1) == 1){
				System.out.println(c.getWarnings());
				System.out.println("OUVERTURE DU COMPTE EFFECTUEE");
				return cp;
			}
			else{
				System.out.println("OUVERTURE DU COMPTE IMPOSSIBLE");
			}
		}
		else{
			System.out.println("OUVERTURE DU COMPTE ANNULEE");
		}
		return "Veuillez recommencer l'operation";
	}
	
	//appelle la fonction ajout_titulaire
	public void ajout_titulaire(String id_cp, String nom, String prenom, int age ) throws SQLException{
		c = co.prepareCall("{call ajout_titulaire(?,?,?,?)}");
		c.setString(1, id_cp);
		c.setString(2, nom);
		c.setString(3, prenom);
		c.setInt(4, age);
		c.execute();
		System.out.println(c.getWarnings());
	}
	
	//appelle la fonction ajout_responsable
	public void ajout_responsable(String id_cp, String nom, String prenom, int age) throws SQLException{
		c = co.prepareCall("{call ajout_responsable(?,?,?,?)}");
		c.setString(1, id_cp);
		c.setString(2, nom);
		c.setString(3, prenom);
		c.setInt(4, age);
		c.execute();
		System.out.println(c.getWarnings());
	}

	//appelle la fonction procuration
	public void procuration(String id_cp, String nom, String prenom, int age, String date, int id_client) throws SQLException{
		c = co.prepareCall("{call procuration(?,?,?,?,?,?)}");
		c.setString(1, id_cp);
		c.setString(2, nom);
		c.setString(3, prenom);
		c.setInt(4, age);
		c.setDate(5, d.valueOf(date));
		c.setInt(6, id_client);
		c.execute();
		System.out.println(c.getWarnings());
	}

	//appelle la fonction fermeture_compte depuis postgresql
	public void ferme_cp(int id_client, String id_cp) throws SQLException{
		CallableStatement c = co.prepareCall("{call fermeture_compte(?,?)}");
		c.setInt(1, id_client);
		c.setString(2, id_cp);
		c.executeQuery();
		System.out.println(c.getWarnings());
	}

	//appelle la fonction consultation depuis postgresql
	public void consult(int id_client, String id_cp) throws SQLException{
		c = co.prepareCall("{call consultation(?,?)}");
		c.setInt(1, id_client);
		c.setString(2, id_cp);
		c.execute();
		System.out.println(c.getWarnings());
	}

	//appelle la fonction virement 
	public void virement_unique(int montant, String cp_em, String ban_rec, String bic_rec, String d_debut) throws SQLException{
		c = co.prepareCall("{call virement(?, ?, ?, ?, ?, ?, ?)}"); 
		c.setInt(1, montant);
		c.setString(2, cp_em);
		c.setString(3, ban_rec);
		c.setString(4, bic_rec);
		c.setDate(5, d.valueOf(d_debut));
		c.setDate(6, d.valueOf(d_debut));
		c.setString(7, "unique");
		c.execute();
		if(c.getWarnings() != null){
			System.out.println(c.getWarnings());
		}
	}

	//appelle la fonction virement
	public void virement_periodique(int montant, String cp_em, String ban_rec, String bic_rec, String d_debut, String d_fin, String periode) throws SQLException{
		c = co.prepareCall("{call virement(?, ?, ?, ?, ?, ?, ?)}");
		c.setInt(1, montant);
		c.setString(2, cp_em);
		c.setString(3, ban_rec);
		c.setString(4, bic_rec);
		c.setDate(5, d.valueOf(d_debut));
		c.setDate(6, d.valueOf(d_fin));
		c.setString(7, periode);
		c.execute();
		if(c.getWarnings() != null){
			System.out.println(c.getWarnings());
		}
	}

	//appelle la fonction retrait
	public void retrait(String id_cp, int montant) throws SQLException{
		c = co.prepareCall("{call retrait(?,?)}");
		c.setString(1, id_cp);
		c.setInt(2, montant);
		c.execute();
		System.out.println(c.getWarnings());
	}

	//appelle la fonction depot_liquide
	public void depot_liquide(String id_cp, int montant) throws SQLException{
		c = co.prepareCall("{? = call depot_liquide(?,?)}");
		c.registerOutParameter(1, Types.INTEGER);
		c.setString(2, id_cp);
		c.setInt(3, montant);
		c.execute();
		System.out.println(c.getWarnings());
		if(c.getInt(1) == 1){
			System.out.println("DEPOT EFFECTUE");
		}
		else{
			System.out.println("DEPOT IMPOSSIBLE");
		}

	}

	//appelle la fonction depot_cheque
	public void depot_cheque(String id_cp, int montant, String id_cp2) throws SQLException{
		c = co.prepareCall("{? = call depot_cheque(?,?,?)}");
		c.registerOutParameter(1,Types.INTEGER);
		c.setString(2, id_cp);
		c.setInt(3, montant);
		c.setString(4, id_cp2);
		c.execute();
		System.out.println(c.getWarnings());
		if(c.getInt(1) == 1){
			System.out.println("DEPOT CHEQUE EFFECTUE");
		}
		else{
			System.out.println("DEPOT CHEQUE IMPOSSIBLE");
		}
	}

	//appelle la fonction releve_personnel
	public void releve(String d_debut, String id_cp) throws SQLException{
		c = co.prepareCall("{call releve_personnel(?,?)}");
		c.setDate(1, d.valueOf(d_debut));
		c.setString(2, id_cp);
		res = c.executeQuery();
		System.out.println("Date operation \tNom operation \tMontant \tNumero compte ");
		System.out.println("___________________________________________________________________");
		while(res != null && res.next()){
			System.out.print(res.getDate("date_operation") + "\t");
			System.out.print(res.getString("nom_operation") + "\t");
			System.out.print(res.getFloat("montant") + "\t\t");
			System.out.print(res.getString("id_compte") + "\n");
			System.out.println("___________________________________________________________________");
		}
	}

	//permet de changer la date du calendrier pour passer au lendemain 
	public int tomorrow() throws SQLException{
		int res2;	
		s = co.createStatement();
		return res2 = s.executeUpdate("update calendrier set d = d + integer '1';");
	}

	//appelle la fonction tolerance
	public void tolerance(String id_cp, int id_cl) throws SQLException{
		int alea = 0 + (int)(Math.random() * (10-0));
		if(alea == 0 || alea > 5){ // cas ou le banquier accepte la demande de tolerance
			c=co.prepareCall("{call tolerance(?, ?)}");
			c.setString(1, id_cp);
			c.setInt(2, id_cl);
			c.execute();
			System.out.println(c.getWarnings());
		}
		else{// refus de la banque pour la demande de tolerance
			System.out.println("DESOLE LA BANQUE N'ACCPETE PAS LA DEMANDE");
			System.out.println(c.getWarnings());
		}
	}
	
	//appelle la fonction retrait_carte
	public void retrait_distrib(String id_cp, int montant, int id_banque) throws SQLException{
		c = co.prepareCall("{call retrait_carte(?,?,?)}");
		c.setString(1, id_cp);
		c.setInt(2, montant);
		c.setInt(3,  id_banque);
		c.execute();
		System.out.println(c.getWarnings());
	}
	
	//appelle la fonction achat_natioanl
	public void achat_natio( String id_cp, int montant) throws SQLException{
		c = co.prepareCall("{call achat_national(?,?)}");
		c.setString(1, id_cp);
		c.setInt(2, montant);
		c.execute();
		System.out.println(c.getWarnings());
	}
	
	//appelle la fonction achat_international
	public void achat_inter(String id_cp, int montant) throws SQLException{
		c = co.prepareCall("{call achat_international(?,?)}");
		c.setString(1, id_cp);
		c.setInt(2, montant);
		c.execute();
		System.out.println(c.getWarnings());
	}
	
}