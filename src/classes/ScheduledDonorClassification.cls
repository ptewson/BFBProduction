/**
* Author: Patrick Tewson - 501 Commons - 2012
* Support the scheduled donor classification rollups
* Stewardship plan, original date October 1, 2012
*/

global with sharing class ScheduledDonorClassification implements Schedulable {

  global void execute(SchedulableContext sc){
      HHDonorClassificationRollups.rollupAllContacts();
  }
}