/**
* Author: Patrick Tewson - NPower NW - 2012
* Utility class used by Donor Classification rollups and HHDonorClassificationRollups trigger.
* This attempts to realize the behavior for donor classification described in the BFB Donor
* Stewardship plan, original date July 18, 2012
*/

public with sharing class HHDonorClassificationRollups {

        static Integer numberSOQL = 0;

        static Boolean testRollups = True;
        static Boolean testLoyal = True;
        static Boolean testMajor = True;
        static Boolean testMonthly = True;
        static Boolean testLapsed = True;


	/**
	* The general contract I'm attempting to adhere to is that the new donor
	* class depends only on the donation history of the contact, NOT the previous 
	* donor state. This will make the whole system more reliable and mean that calling
	* this class on all the contacts can set the correct donor class independent of 
	* initial conditions.
	**/
	public static void rollupAllContacts() {
		// nothing yet
		Integer batchSize = 200;

                BATCH_DonorClassRollups batch = new BATCH_DonorClassRollups
        	     ('select id, Always_classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c');

                id batchProcessId = database.executeBatch(batch, batchSize);  
	}	


	public static void rollupDonorClass(List<npo02__Household__c> households) {
            Map<Id, npo02__Household__c> hhMap = new Map<Id,npo02__Household__c>();
            for(npo02__Household__c hh: households) {
               hhMap.put(hh.id, hh);
            }

            // get all the contacts attached to any of the households
            Map<Id, Contact> contactMap = new Map<Id, Contact>([SELECT id, npo02__Household__c from Contact where npo02__Household__c =: hhMap.keySet()]);
            numberSOQL++;

            // get all the opportunitycontactroles related to these contacts
            List<OpportunityContactRole> ocrs = 
                [SELECT OpportunityId, ContactId from OpportunityContactRole where ContactId =: contactMap.keySet() and IsPrimary = True];
            numberSOQL++;

            List<Id> oids = new List<Id>();
            for(OpportunityContactRole ocr: ocrs) {
                oids.add(ocr.OpportunityId);
                //System.debug('************ (Map Builder) Contact Role OppID: '+ocr.OpportunityId);
            }

            // get all the opportunities attached to the above OCRS
            Map<Id,Opportunity> oppMap = new Map<Id,Opportunity>([SELECT o.id, o.AccountID, a.Name, o.CloseDate, 
                o.RecordTypeId, o.Amount from Opportunity o, o.Account a where StageName =: 'Closed Won' and id =: oids]);
            numberSOQL++;


            // now we must attach donations to household
            Map<id,List<Opportunity>> householdsAndDonations = new Map<Id,List<Opportunity>>();
            for(OpportunityContactRole ocr: ocrs) {
                Id hhid = contactMap.get(ocr.ContactId).npo02__Household__c;
                if(!householdsAndDonations.containsKey(hhid)) {
                    householdsAndDonations.put(hhid, new List<Opportunity>());
                }
                Opportunity opp = oppMap.get( ocr.OpportunityId );
                if(opp != null) householdsAndDonations.get(hhid).add( opp );
            }

            rollupDonorClass(hhMap, householdsAndDonations);

	}


	public static void rollupDonorClass(Set<id> newOppIds) {

		for(id oid: newOppIds) {
			System.debug(' ******** Orig Op ID: '+ oid);
		}

                List<Contact> contacts = [SELECT id, npo02__household__r.id from Contact where id in 
			(select ContactId from OpportunityContactRole where OpportunityId =: newOppIds and IsPrimary = True)];
                numberSOQL++;


		for(Contact c: contacts) {
			System.debug(' ******** Attached Contact ID, Household: '+ c.id +', '+c.npo02__Household__c);
		}

                List<Id> hhids = new List<Id>();
                for(Contact c: contacts) hhids.add(c.npo02__household__r.id);

                List<npo02__Household__c> households = [SELECT id, Always_classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c where id =: hhids];


                for(npo02__Household__c hh: households) {
			System.debug(' ******** Household ID: '+hh.id);
                }
                rollupDonorClass(households);

	}
		
	public static void rollupDonorClass(Map<Id, npo02__Household__c> householdMap, Map<Id,List<Opportunity>> householdsAndDonations) {

                List<npo02__Household__c> hhToUpdate = new List<npo02__Household__c>();
			
		for(npo02__Household__c hh: householdMap.values()) {
                        String prevDonorClass = hh.Donor_Classification__c;
                        if(prevDonorClass == null) prevDonorClass = '';

                        Boolean alwaysMajorDonor = False;
                        if(hh.Always_classify_as_Major_Donor__c != null && hh.Always_classify_as_Major_Donor__c) alwaysMajorDonor = True;

                        

			// No donations? No classification! Set to blank and move on - unless there's an override
			if((!householdsAndDonations.containsKey(hh.id) || householdsAndDonations.get(hh.id).size() == 0) && !alwaysMajorDonor) {
                                if(!donorClassEquivalent('',prevDonorClass)) {
                                  hh.Previous_Donor_Classification__c = prevDonorClass;
                                  hh.Donor_Classification_Transition_Date__c = System.now();
                                } 
				hh.Donor_Classification__c = '';
                                hhToUpdate.add(hh);
				continue;
			}
			
			Date lastGiftDate = null;
			String currentDonorClass = '';   //c.Donor_Classification__c;
			if(currentDonorClass == null) {
				currentDonorClass = '';
			}
			for(Opportunity o: householdsAndDonations.get(hh.id)) {
				if(lastGiftDate == null) {
					lastGiftDate = o.CloseDate;
				} else if(o.CloseDate > lastGiftDate) {
					lastGiftDate = o.CloseDate;
				}
			}

			Date compareDate = Date.today();
			compareDate = compareDate.addYears(-1);
			
                        if(lastGiftDate != null) {
                          System.debug(' ******* last gift date, compare, diff, #donations: '+lastGiftDate + ', '+compareDate +', ' + 
                               lastGiftDate.daysBetween(compareDate)+', '+householdsAndDonations.get(hh.id).size());
                          if(householdsAndDonations.get(hh.id).size() == 1 && lastGiftDate.daysBetween(compareDate) < 0) {
                            if(!currentDonorClass.contains('First Time Donor')) {
                              currentDonorClass =  'First Time Donor';	
                            }
                          } else if(householdsAndDonations.get(hh.id).size() > 1 && lastGiftDate.daysBetween(compareDate) < 0) {
                            if(!currentDonorClass.contains('Renewing Donor')) {
                              currentDonorClass =  'Renewing Donor';	
                            }
                          } else if(householdsAndDonations.get(hh.id).size() == 1 && lastGiftDate.daysBetween(compareDate) >= 0) {
                            if(!currentDonorClass.contains('One Time Donor')) {
                              currentDonorClass = 'One Time Donor';	
                            }
                          } if(householdsAndDonations.get(hh.id).size() > 1) {
                            currentDonorClass = currentDonorClass.replace('First Time Donor','');
                          }

                          // Let's just throw in "Lapsed" as four years w/ no donation for now
                          compareDate = compareDate.addYears(-3);
                          if(lastGiftDate.daysBetween(compareDate) > 0) {
                            if(!currentDonorClass.contains('Lapsed Donor')) {
                              currentDonorClass = 'Lapsed Donor';	
                            }
                          }
                        }

                        Double lastYearGiving = 0;
		        Date todaysDate = Date.today().addYears(-1);
                        // override
                        if(!alwaysMajorDonor) {
                          // 'Major Donor' means >= 1000 dollars giving in the last calendar year
                          Integer lastYear = todaysDate.year();
                          for(Opportunity opp: householdsAndDonations.get(hh.id)) {
                            if(opp.closeDate.year() == lastYear) {
                              lastYearGiving += opp.Amount;
                              System.debug(' ********* total giving for donor, opp amount: '+lastYearGiving+', '+opp.Amount);
                            }
                          }
                        }
                        if(lastYearGiving >= 1000.0 || alwaysMajorDonor) {
  			   if(!currentDonorClass.contains('Major Donor')) {
			     currentDonorClass = currentDonorClass + '; Major Donor';	
			   }
                        } else {
    		           currentDonorClass.replace('Major Donor','');	
                        }
			
			// The "Loyal Donor" class involves donating 5 years in the last 6
			Integer numberYearsDonated = 0;
			// start with last year else things get weird with this incomplete year
			todaysDate = Date.today();
			for(Date aYear = todaysDate.addYears(-1); todaysDate.year() - aYear.year() <= 6; aYear = aYear.addYears(-1)) {
				System.debug(' ******* year, numberYearsDonated: ' + aYear.year()+', '+numberYearsDonated);
				for(Opportunity opp : householdsAndDonations.get(hh.id)) {
					if(opp.CloseDate.year() == aYear.year()) {
						numberYearsDonated++;
						break;
					}
				}
			}
			if(numberYearsDonated >= 5) {
				if(!currentDonorClass.contains('Loyal Donor')) {
					currentDonorClass = currentDonorClass + '; Loyal Donor';
				}
			} else {
				currentDonorClass = currentDonorClass.replace('Loyal Donor','');
			}
			
			// The "Monthly Donor" class involves donating consecutively 3 months w/in the last 6
			todaysDate = Date.today();
			// go back 3 months for the start of reconing
			Boolean isMonthlyDonor = false;
			
			// set up three months of history, we'll be sliding each of these back
			Date oneMonthBack = todaysDate.addMonths(-1);
			Date twoMonthsBack = oneMonthBack.addMonths(-1);
			Date threeMonthsBack = twoMonthsBack.addMonths(-1);
			
			// we are interested in 6 months but the end of our window is only 3 months ago
			while(todaysDate.month() - oneMonthBack.month() <= 3) {
				Boolean hitOneMonthBack = false;
				Boolean hitTwoMonthsBack = false;
				Boolean hitThreeMonthsBack = false;
				
				System.debug(' ******** One month back:    '+oneMonthBack.year()+', '+oneMonthBack.month()+': '+hitOneMonthBack); 
				System.debug(' ******** Two months back:   '+twoMonthsBack.year()+', '+twoMonthsBack.month()+': '+hitTwoMonthsBack);
				System.debug(' ******** Three months back: '+threeMonthsBack.year()+', '+threeMonthsBack.month()+': '+hitThreeMonthsBack);
				// Copy the date, we'll be backing this one up as we identify matches
				for(Opportunity opp : householdsAndDonations.get(hh.id)) {
					// if monnth and year match...
					Integer closeMonth = opp.CloseDate.month();
					Integer closeYear = opp.CloseDate.year();
					System.debug(' ******** Testing opp at: '+closeYear+', '+closeMonth);
					System.debug(' ******** Current donation hits (one,two,three): '+hitOneMonthBack+', '+hitTwoMonthsBack+', '+hitThreeMonthsBack);
					if(closeMonth == oneMonthBack.month() && closeYear == oneMonthBack.year())
						hitOneMonthBack = true;
					if(closeMonth == twoMonthsBack.month() && closeYear == twoMonthsBack.year())
						hitTwoMonthsBack = true;
					if(closeMonth == threeMonthsBack.month() && closeYear == threeMonthsBack.year())
						hitThreeMonthsBack = true; 
					// did we find three consecutive months?
					if(hitOneMonthBack && hitTwoMonthsBack && hitThreeMonthsBack) {
						isMonthlyDonor = true;
						break;
					}
				}
				// if we have already identified donor as monthly, we're done here.
				if(isMonthlyDonor) break;
				
				// if not, slide everything back 1 month and try again
				oneMonthBack = oneMonthBack.addMonths(-1);
				twoMonthsBack = twoMonthsBack.addMonths(-1);
				threeMonthsBack = threeMonthsBack.addMonths(-1);
			}
			if(isMonthlyDonor) {
				if(!currentDonorClass.contains('Monthly Donor')) {
					currentDonorClass = currentDonorClass + '; Monthly Donor';
				}
			} else {
				currentDonorClass = currentDonorClass.replace('Monthly Donor','');
			}
	
			System.debug(' ******* attempting to set donor class: '+currentDonorClass);
			hh.Donor_Classification__c = currentDonorClass;

                        System.debug(' ******* Donor class - new, prev ' + currentDonorClass +' '+ prevDonorClass);
                        if(!donorClassEquivalent(currentDonorClass,prevDonorClass)) {
                            hh.Previous_Donor_Classification__c = prevDonorClass;
                            hh.Donor_Classification_Transition_Date__c = System.now();
                        } 
			//update c;
                        hhToUpdate.add(hh);
		}
                update hhToUpdate;
                System.debug('********* *I* think I used '+numberSOQL+ ' queries');
	}

        static Boolean donorClassEquivalent(String class1, String class2) {
            Set<String> tokens1 = new Set<String>(); //class1.split(';'));
            Set<String> tokens2 = new Set<String>(class2.split(';'));
            
            for(String token: class1.split(';')) {
              tokens1.add(token.trim());
            }

            if(tokens1.size() != tokens2.size()) return false;

            for(String token: tokens2) {
               if(!tokens1.contains(token.trim())) return false;
            }
            return true;
        }

	static testMethod void testDonorClassificationRollups() {

                if(!testRollups) return;

                Test.startTest();

                npo02__Household__c hh = new npo02__Household__c(Name='Testerson Household');
                insert hh;

		Contact c = new Contact(FirstName = 'Test', LastName = 'Testerson', npo02__Household__c = hh.id);
		insert c;

		System.assertEquals(hh.Donor_Classification__c, null);
		
		Program__c p = new Program__c(Name = 'Test');
		insert p;
		
		Campaign camp = new Campaign(Name = 'Test');
		insert camp;
		
                Account individual = new Account(Name = 'Individual');
                insert individual;


		Opportunity o = new Opportunity(Name = 'Test Donation');
		o.Amount = 1.00;
                o.Account = individual;
		o.CloseDate = Date.today();
		o.npe01__Contact_Id_for_Role__c = c.Id;
		o.Program__c = p.Id;
		o.CampaignId = camp.id;
		o.Type = 'Individual';
		o.StageName = 'Pending';
		o.Payment_Method__c = 'Cash';
		insert o;
		
		OpportunityContactRole ocr = new OpportunityContactRole();
		ocr.ContactId = c.id;
		ocr.OpportunityId = o.id;
		ocr.IsPrimary = true;
		insert ocr;
		
                
		o.StageName = 'Closed Won';
		update o;
		
		OpportunityContactRole[] roles = [select id from OpportunityContactRole where OpportunityID =: o.id];

		System.assert(roles.size() > 0);
		
		Contact[] updated = [select id, npo02__Household__c from Contact where id =: c.id];
                List<Id> hhids = new List<Id>();
                for(contact cont: updated) {
                   hhids.add(cont.npo02__Household__c);
                   System.debug('*********** Household ID: '+cont.npo02__Household__c);
                }

                System.assertEquals(hhids.size(), 1);
                List<npo02__Household__c> hhs = [SELECT id, Always_Classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c where id =: hhids];
                rollupDonorClass(hhs);


                System.assertEquals(hhs.size(), 1);
		System.assertEquals(hhs.get(0).Donor_Classification__c, 'First Time Donor');
		
                Test.stopTest();

                System.debug('********* *I* think I used '+numberSOQL+ ' queries');
	}

	static testMethod void testLoyalDonor() {

                if(!testLoyal) return;
                
                Test.startTest();
                npo02__Household__c hh = new npo02__Household__c(Name='Testerson Household');
                insert hh;

		Contact c = new Contact(FirstName = 'Test', LastName = 'Testerson', npo02__Household__c=hh.id);
		insert c;
		
		System.assertEquals(hh.Donor_Classification__c, null);
		
		Program__c p = new Program__c(Name = 'Test');
		insert p;
		
		Campaign camp = new Campaign(Name = 'Test');
		insert camp;
		
                Account individual = new Account(Name = 'Individual');
                insert individual;

                // Test Loyal Donor
                Date today = Date.today();
                List<Opportunity> opps = new List<Opportunity>();
                List<OpportunityContactRole> ocrs = new List<OpportunityContactRole>();
                for(Integer i=0; i<6; i++) {
               	  Opportunity opp = new Opportunity(Name = 'Test Donation');
		  opp.Amount = 1.00;
                  opp.Account = individual;
		  opp.CloseDate = today.addYears(-1 * i);
		  opp.npe01__Contact_Id_for_Role__c = c.Id;
		  opp.Program__c = p.Id;
		  opp.CampaignId = camp.id;
		  opp.Type = 'Individual';
		  opp.StageName = 'Pending';
		  opp.Payment_Method__c = 'Cash';
		  //insert opp;
                  opps.add(opp);
                }

                insert(opps);

                for(Opportunity anOpp: opps) {
		  OpportunityContactRole cr = new OpportunityContactRole();
		  cr.ContactId = c.id;
		  cr.OpportunityId = anOpp.id;
		  cr.IsPrimary = true;
		  //insert cr;
                  ocrs.add(cr);

                }
                insert(ocrs);

                List<Opportunity> updatedOpps = new List<Opportunity>();
                for(Opportunity anotherOpp: opps) {
                  anotherOpp.StageName = 'Closed Won';
                  updatedOpps.add(anotherOpp);
                }
                update(updatedOpps);

		Contact[] updated = [select id, npo02__Household__c from Contact where id =: c.id];
                List<Id> hhids = new List<Id>();
                for(contact cont: updated) {
                   hhids.add(cont.npo02__Household__c);
                   System.debug('*********** TESTLOYAL Household ID: '+cont.npo02__Household__c);
                }

                System.assertEquals(hhids.size(), 1);
                List<npo02__Household__c> hhs = [SELECT id, Always_Classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c where id =: hhids];

		System.assert(hhs.get(0).Donor_Classification__c.contains('Loyal Donor'));

                Test.stopTest();

                System.debug('********* *I* think I used '+numberSOQL+ ' queries');
	}

	static testMethod void testLapsedDonor() {

                if(!testLapsed) return;

                Test.startTest();
                npo02__Household__c hh = new npo02__Household__c(Name='Testerson Household');
                insert hh;

		Contact c = new Contact(FirstName = 'Test', LastName = 'Testerson', npo02__Household__c=hh.id);
		insert c;
		
		System.assertEquals(hh.Donor_Classification__c, null);
		
		Program__c p = new Program__c(Name = 'Test');
		insert p;
		
		Campaign camp = new Campaign(Name = 'Test');
		insert camp;
		
                Account individual = new Account(Name = 'Individual');
                insert individual;

		Opportunity o = new Opportunity(Name = 'Test Donation');
		o.Amount = 1.00;
                o.Account = individual;
		o.CloseDate = Date.today();
		o.npe01__Contact_Id_for_Role__c = c.Id;
		o.Program__c = p.Id;
		o.CampaignId = camp.id;
		o.Type = 'Individual';
		o.StageName = 'Pending';
		o.Payment_Method__c = 'Cash';
		insert o;
		
		OpportunityContactRole ocr = new OpportunityContactRole();
		ocr.ContactId = c.id;
		ocr.OpportunityId = o.id;
		ocr.IsPrimary = true;
		insert ocr;
		
		o.StageName = 'Closed Won';
                // test lapsed donor
                Date today = Date.today();
                o.CloseDate = today.addYears(-5);
                update o;

	        Contact[] updated = [select id, npo02__Household__c from Contact where id =: c.id];
                List<Id> hhids = new List<Id>();
                for(contact c2: updated) {
                  hhids.add(c2.npo02__Household__c);
                }
                List<npo02__Household__c> hhs = [SELECT id, Always_Classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c where id =: hhids];

		System.assert(hhs.get(0).Donor_Classification__c.contains('Lapsed Donor'));

                Test.stopTest();
                System.debug('********* *I* think I used '+numberSOQL+ ' queries');
	}

	static testMethod void testMonthly() {

                if(!testMonthly) return;

                Test.startTest();

                npo02__Household__c hh = new npo02__Household__c(Name='Testerson Household');
                insert hh;

		Contact c = new Contact(FirstName = 'Test', LastName = 'Testerson', npo02__Household__c=hh.id);
		insert c;
		
		System.assertEquals(hh.Donor_Classification__c, null);
		
		Program__c p = new Program__c(Name = 'Test');
		insert p;
		
		Campaign camp = new Campaign(Name = 'Test');
		insert camp;

                Account individual = new Account(Name = 'Individual');
                insert individual;

                // Test Monthly Donor
                Date today = Date.today();
                List<Opportunity> opps = new List<Opportunity>();
                List<OpportunityContactRole> ocrs = new List<OpportunityContactRole>();
                for(Integer i=0; i<6; i++) {
               	  Opportunity opp = new Opportunity(Name = 'Test Donation');
		  opp.Amount = 1.00;
                  opp.Account = individual;
		  opp.CloseDate = today.addMonths(-1 * i);
		  opp.npe01__Contact_Id_for_Role__c = c.Id;
		  opp.Program__c = p.Id;
		  opp.CampaignId = camp.id;
		  opp.Type = 'Individual';
		  opp.StageName = 'Pending';
		  opp.Payment_Method__c = 'Cash';
		  //insert opp;
                  opps.add(opp);
                }

                insert(opps);

                for(Opportunity anOpp: opps) {
		  OpportunityContactRole cr = new OpportunityContactRole();
		  cr.ContactId = c.id;
		  cr.OpportunityId = anOpp.id;
		  cr.IsPrimary = true;
		  //insert cr;
                  ocrs.add(cr);

                }
                insert(ocrs);

                List<Opportunity> updatedOpps = new List<Opportunity>();
                for(Opportunity anotherOpp: opps) {
                  anotherOpp.StageName = 'Closed Won';
                  updatedOpps.add(anotherOpp);
                }
                update(updatedOpps);

		Contact[] updated = [select id, npo02__Household__c from Contact where id =: c.id];
                List<Id> hhids = new List<Id>();
                for(contact cont: updated) {
                   hhids.add(cont.npo02__Household__c);
                   System.debug('*********** TESTMONTHLY Household ID: '+cont.npo02__Household__c);
                }

                System.assertEquals(hhids.size(), 1);
                List<npo02__Household__c> hhs = [SELECT id, Always_Classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c where id =: hhids];

		System.assert(hhs.get(0).Donor_Classification__c.contains('Monthly Donor'));

                Test.stopTest();

                System.debug('********* *I* think I used '+numberSOQL+ ' queries');
	}

	static testMethod void testMajor() {

                if(!testMajor) return;

		System.debug(' ******* MAJOR DONOR TEST');

                Test.startTest();

                npo02__Household__c hh = new npo02__Household__c(Name='Testerson Household');
                insert hh;

		Contact c = new Contact(FirstName = 'Test', LastName = 'Testerson', npo02__Household__c=hh.id);
		insert c;

		System.assertEquals(hh.Donor_Classification__c, null);

		Program__c p = new Program__c(Name = 'Test');
		insert p;
		
		Campaign camp = new Campaign(Name = 'Test');
		insert camp;

                Account individual = new Account(Name = 'Individual');
                insert individual;

                // Test Monthly Donor
                Date today = Date.today().addYears(-1);
                List<Opportunity> opps = new List<Opportunity>();
                List<OpportunityContactRole> ocrs = new List<OpportunityContactRole>();
                for(Integer i=0; i<6; i++) {
               	  Opportunity opp = new Opportunity(Name = 'Test Donation');
		  opp.Amount = ((i+1)*100)+400;
                  opp.Account = individual;
		  opp.CloseDate = today;
		  opp.npe01__Contact_Id_for_Role__c = c.Id;
		  opp.Program__c = p.Id;
		  opp.CampaignId = camp.id;
		  opp.Type = 'Individual';
		  opp.StageName = 'Pending';
		  opp.Payment_Method__c = 'Cash';
		  //insert opp;
                  opps.add(opp);
                }

                insert(opps);

                for(Opportunity anOpp: opps) {
		  OpportunityContactRole cr = new OpportunityContactRole();
		  cr.ContactId = c.id;
		  cr.OpportunityId = anOpp.id;
		  cr.IsPrimary = true;
		  //insert cr;
                  ocrs.add(cr);

                }
                insert(ocrs);

                List<Opportunity> updatedOpps = new List<Opportunity>();
                for(Opportunity anotherOpp: opps) {
                  anotherOpp.StageName = 'Closed Won';
                  updatedOpps.add(anotherOpp);
                }
                update(updatedOpps);

		Contact[] updated = [select id, npo02__Household__c from Contact where id =: c.id];
                List<Id> hhids = new List<Id>();
                for(contact cont: updated) {
                   hhids.add(cont.npo02__Household__c);
                   System.debug('*********** TESTMAJOR Household ID: '+cont.npo02__Household__c);
                }

                System.assertEquals(hhids.size(), 1);
                List<npo02__Household__c> hhs = [SELECT id, Always_Classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c where id =: hhids];

		System.assert(hhs.get(0).Donor_Classification__c.contains('Major Donor'));


                npo02__Household__c hh2 = new npo02__Household__c(Name='Testerson Household', Always_Classify_As_Major_Donor__c = True);
                insert hh2;

		Contact c2 = new Contact(FirstName = 'Test', LastName = 'Testerson', npo02__Household__c=hh2.id);
                //c2.Always_classify_as_Major_donor__c = True;
		insert c2;

                // have to insert an opp here to get the trigger to fire
              	Opportunity opp2 = new Opportunity(Name = 'Another Test Donation');
		opp2.Amount = 4;
                opp2.Account = individual;
		opp2.CloseDate = today;
		opp2.npe01__Contact_Id_for_Role__c = c2.Id;
		opp2.Program__c = p.Id;
		opp2.CampaignId = camp.id;
		opp2.Type = 'Individual';
		opp2.StageName = 'Pending';
		opp2.Payment_Method__c = 'Cash';
		insert opp2;

	        OpportunityContactRole cr2 = new OpportunityContactRole();
		cr2.ContactId = c2.id;
		cr2.OpportunityId = opp2.id;
		cr2.IsPrimary = true;
		insert cr2;

		opp2.StageName = 'Closed Won';
                update opp2;

	        updated = [select id, npo02__Household__c from Contact where id =: c2.id];

                hhids = new List<Id>();
                for(contact cont: updated) {
                   hhids.add(cont.npo02__Household__c);
                   System.debug('*********** TESTMAJOR Household ID: '+cont.npo02__Household__c);
                }

                System.assertEquals(hhids.size(), 1);
                hhs = [SELECT id, Always_Classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c where id =: hhids];

		System.assertEquals(hhs.get(0).Donor_Classification__c.contains('Major Donor'), True);

                //c2.Always_classify_as_Major_donor__c = False;
                hh2.Always_classify_as_Major_Donor__c = False;
                update hh2;
		opp2.StageName = 'Closed Won';
                // have to update an opp here to get the trigger to fire
                update opp2;
	        updated = [select id, npo02__Household__c from Contact where id =: c2.id];
                hhids = new List<Id>();
                for(contact cont: updated) {
                   hhids.add(cont.npo02__Household__c);
                   System.debug('*********** TESTMAJOR Household ID: '+cont.npo02__Household__c);
                }

                System.assertEquals(hhids.size(), 1);
                hhs = [SELECT id, Always_Classify_as_Major_Donor__c, Donor_Classification__c from npo02__Household__c where id =: hhids];

		//System.assertEquals(hhs.get(0).Donor_Classification__c.contains('Major Donor'), False);

                Test.stopTest();

                System.debug('********* *I* think I used '+numberSOQL+ ' queries');
	}

	static testMethod void testDonorClassEquivalency() {
            String s1 = 'Monthly Donor; Renewing Donor';
            String s2 = 'Renewing Donor; Monthly Donor';
            String s3 = 'Renewing Donor; Monthly Donor; Lapsed Donor';
            String s4 = 'Renewing DOnor; Lapsed Donor';
            
            System.assertEquals(donorClassEquivalent(s1,s2), true);
            System.assertEquals(donorClassEquivalent(s1,s3), false);
            System.assertEquals(donorClassEquivalent(s1,s4), false);
          
        }
}