public with sharing class MarkDonationsThankedController {
	public List<TableRow> tableRows { get; set; }
	public List<Contact> allStewardedContacts { get; set; } 
	public List<Account> allStewardedAccounts { get; set; } 
	public List<OrgTableRow> orgTableRows { get; set; }

        public Boolean loadedDonations { get; set; }
        public Boolean filterBlankPhone { get; set; }



	public class TableRow {
		public Contact theContact { get; set; }
		public Opportunity theDonation { get; set; }	
	
		public TableRow(Opportunity o, Contact c) {
			theDonation = o;
			theContact = c;
		}
		 
		public void updateThis() {
			//update theContact;
			update theDonation; 
		}
	}

	public class OrgTableRow {
		public Account theAccount { get; set; }
		public Opportunity theDonation { get; set; }	
	
		public OrgTableRow(Opportunity o, Account a) {
			theDonation = o;
			theAccount = a;
		}
		 
		public void updateThis() {
			update theDonation; 
		}
	}
	 

	public String donorSteward;
	public String donorClassification { get; set; }
	
        public MarkDonationsThankedController() {
            loadedDonations = False;
            filterBlankPhone = True;

        }

	public String getDonorSteward() {
		return donorSteward;  
	}
	
	public void setDonorSteward(String donorSteward) {
		this.donorSteward = donorSteward;
	}
	
	public String getInfo(){
		return 'this is REALLY the controller text';
	}
	
	public PageReference invokeService() { 

                // Handle all the contact donations
		Opportunity[] donations;
		// opp ID and corresponding contact ID
		Map<Id, Id> donorContactIDMap = new Map<Id, Id>();
		// contact ID and corresponding contact
		Map<Id, Contact> contactMap = new Map<Id, Contact>();
                if(donorClassification == null) donorClassification = '';
		//String donorSteward = System.currentPageReference().getParameters().get('donorsteward');
                if(filterBlankPhone) {
                  if(donorClassification.equals('All')) {
		    donations = [select o.AccountId, a.Name, o.Name, o.Id, o.CloseDate, o.Amount, o.StageName, o.Donor_Called__c, o.Program__c,
		      (select OpportunityId, IsPrimary from OpportunityContactRoles where IsPrimary = True) from Opportunity o, o.Account a
		      where Opportunity.Donor_Called__c != True and (a.Name = 'Individual' or o.AccountId = null) and o.StageName = 'Closed Won' and id in 
		      (Select OpportunityId from OpportunityContactRole where ContactId != '' and Contact.Phone != '' and
		      Contact.Contact_Preference__c != 'No Contact' and Contact.Deceased__c != true and
		      Contact.Donor_Steward__c =: donorSteward) limit 30];
                  } else {
		    donations = [select o.AccountId, a.Name, o.Name, o.Id, o.CloseDate, o.Amount, o.StageName, o.Donor_Called__c, o.Program__c, 
		      (select OpportunityId, IsPrimary from OpportunityContactRoles where IsPrimary = True) from Opportunity o, o.Account a
		      where Opportunity.Donor_Called__c != True and (a.Name = 'Individual' or o.AccountId = null) and o.StageName = 'Closed Won' and id in 
		      (Select OpportunityId from OpportunityContactRole where ContactId != '' and Contact.Phone != '' and
		      Contact.Contact_Preference__c != 'No Contact' and Contact.Deceased__c != true and 
                      Contact.Donor_Classification__c like :('%'+donorClassification+'%') and
		      Contact.Donor_Steward__c =: donorSteward) limit 30];
                  }
                } else {
                  if(donorClassification.equals('All')) {
		    donations = [select o.AccountId, a.Name, o.Name, o.Id, o.CloseDate, o.Amount, o.StageName, o.Donor_Called__c, o.Program__c,
		      (select OpportunityId, IsPrimary from OpportunityContactRoles where IsPrimary = True) from Opportunity o, o.Account a
		      where Opportunity.Donor_Called__c != True and (a.Name = 'Individual' or o.AccountId = null) and o.StageName = 'Closed Won' and id in 
		      (Select OpportunityId from OpportunityContactRole where ContactId != '' and 
		      Contact.Contact_Preference__c != 'No Contact' and Contact.Deceased__c != true and
		      Contact.Donor_Steward__c =: donorSteward) limit 30];
                  } else {
		    donations = [select o.AccountId, a.Name, o.Name, o.Id, o.CloseDate, o.Amount, o.StageName, o.Donor_Called__c, o.Program__c, 
		      (select OpportunityId, IsPrimary from OpportunityContactRoles where IsPrimary = True) from Opportunity o, o.Account a
		      where Opportunity.Donor_Called__c != True and (a.Name = 'Individual' or o.AccountId = null) and o.StageName = 'Closed Won' and id in 
		      (Select OpportunityId from OpportunityContactRole where ContactId != '' and 
		      Contact.Contact_Preference__c != 'No Contact' and Contact.Deceased__c != true and 
                      Contact.Donor_Classification__c like :('%'+donorClassification+'%') and
		      Contact.Donor_Steward__c =: donorSteward) limit 30];
                  }
                }
		for(Opportunity opp: donations) {
			donorContactIDMap.put(opp.id, null);
		}
		for(OpportunityContactRole ocr: [select ContactID, OpportunityID, IsPrimary from OpportunityContactRole 
		    where IsPrimary = True and OpportunityContactRole.OpportunityId in :donorContactIDMap.keySet()]) {
			donorContactIDMap.put(ocr.OpportunityID, ocr.ContactId);				
		}
			
                for(Contact c: [select c.Name, c.Id, c.email, c.Phone, c.MailingStreet, c.MailingCity, c.MailingState, c.MailingPostalCode, c.Donor_Classification__c, c.npo02__Household__c, h.Name
		    from Contact c, c.npo02__Household__r h where id in :donorContactIdMap.values() limit 200]) {
			contactMap.put(c.id, c);
		}
		
		//if(!donorSteward.equals('')) {
		if(donorSteward != null) {
			allStewardedContacts = [select c.Name, c.Id, c.email, c.Phone, c.MailingStreet, c.MailingCity, c.MailingState, c.MailingPostalCode, c.Donor_Classification__c, c.npo02__Household__c, h.Name, c.npo02__LastCloseDate__c, c.npo02__LastOppAmount__c
				from Contact c, c.npo02__Household__r h where Donor_Steward__c =: donorSteward limit 200];
		} else {
			allStewardedContacts = null;
		}
		List<TableRow> rows = new List<TableRow>();
		for(Opportunity o: donations) {
			rows.add(new TableRow(o, contactMap.get(donorContactIDMap.get(o.id))));
		}
		tableRows = rows;
		


		// account ID and corresponding account
                Map<Id,Account> accounts = new Map<Id,Account>([select Id, Name, Phone, BillingStreet, BillingCity, BillingState, BillingPostalCode 
                              from Account where Name != 'Individual' and Donor_Steward__c =: donorSteward limit 100]);
                // opp ID and the corresponding opp
                Map<Id,Opportunity> orgDonations = new Map<Id,Opportunity>([select Id, AccountId, Name, CloseDate, Amount, StageName, Donor_Called__c from Opportunity where Donor_Called__c != True and StageName = 'Closed Won' and AccountId =: accounts.keySet() limit 100]);

                // build up the map connecting things
                List<OrgTableRow> orows = new List<OrgTableRow>();
                for(Id oid: orgDonations.keySet()) {
                    orows.add(new OrgTableRow(orgDonations.get(oid), accounts.get((orgDonations.get(oid)).AccountId)));
                }
                orgTableRows = orows;

                allStewardedAccounts = new List<Account>();
                if(donorSteward != null) {
                    for(Id aid: accounts.keySet()) {
                        allStewardedAccounts.add(accounts.get(aid));
                    }
                }

                if(tableRows.size() > 0 || orgTableRows.size() > 0) loadedDonations = True;
                else loadedDonations = False;

		return null; 
	}
	
	public PageReference markThanked() { 
                List<Opportunity> opps = new List<Opportunity>();
		for(TableRow row: tableRows) {
                  opps.add(row.theDonation);
                }
                update opps;

                opps = new List<Opportunity>();
		for(OrgTableRow row: orgTableRows) {
                  opps.add(row.theDonation);
                }
                update opps;

		return invokeService();
	}
		
	public List<SelectOption> getDonorStewards() {
		List<SelectOption> options = new List<SelectOption>();
		options.add(new SelectOption('None','Select your name'));
		options.add(new SelectOption('','No Specified Donor Steward'));
		Schema.DescribeFieldResult fieldResult = Contact.Donor_Steward__c.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for(Schema.PicklistEntry p : ple)
			options.add(new SelectOption(p.getValue(),p.getValue()));
		return options;
	}

	public List<SelectOption> getDonorClassifications() {
		List<SelectOption> options = new List<SelectOption>();
		options.add(new SelectOption('All','All donor classifications'));
		options.add(new SelectOption('','None'));
		Schema.DescribeFieldResult fieldResult = npo02__Household__c.Donor_Classification__c.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for(Schema.PicklistEntry p : ple)
			options.add(new SelectOption(p.getValue(),p.getValue()));
		return options;
                //return new List<SelectOption>();
	}
	
	static testMethod void testController() {
		MarkDonationsThankedController mdtc = new MarkDonationsThankedController();
		//mdtc.getDonations();
		//mdtc.getDonorStewards();
				
		mdtc.setDonorSteward('bob');
		
		List<SelectOption> options = mdtc.getDonorStewards();
		
		mdtc.invokeService();
		System.assertEquals('bob',mdtc.getDonorSteward());

                mdtc.donorClassification = 'All';
		mdtc.invokeService();

                mdtc.donorClassification = 'First Time Donor';
		mdtc.invokeService();

                mdtc.markThanked();

		//System.assertEquals(mdtc.getInfo(),  'this is the controller text');
	}
}
