global class BATCH_DonorClassRollups implements Database.Batchable<SObject> {
// batch apex class to rollup opportunities
	
	public String query { get; set; }
	
	// constructors
	public BATCH_DonorClassRollups(string q) {   
		query = q; 
	}
	
	global database.Querylocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);		 
	}
	
	global /* public */ void execute(Database.BatchableContext bc, Sobject[] result) {
		
 		if (result[0].getSObjectType() == npo02__Household__c.sObjectType) { 
			HHDonorClassificationRollups.rollupDonorClass((List<npo02__Household__c>)result);
 		}  		
	}

	global void finish(Database.BatchableContext bc) {
	}

	public static testMethod void testBatch() {
           // not yet
	}
}