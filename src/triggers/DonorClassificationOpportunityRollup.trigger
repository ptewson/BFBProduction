trigger DonorClassificationOpportunityRollup on Opportunity (before delete, after insert, after update) {
	if(trigger.isInsert || trigger.isUpdate){
		// prevent troubles with bulk adds
		if(trigger.newMap.keySet().size() <= 10) HHDonorClassificationRollups.rollupDonorClass(trigger.newMap.keySet()); 
	} 
	else if(trigger.isDelete) {
	      // prevent troubles with bulk deletes
	      if(trigger.oldMap.keySet().size() <= 10) HHDonorClassificationRollups.rollupDonorClass(trigger.oldMap.keySet());
	}
}