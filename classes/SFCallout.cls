/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 07-05-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class SFCallout {
  // Get records from source org
  public static void getSourceOrgData(String objectName) {
    String query = getStringQuery(objectName);

    HttpResponse response = CalloutServices.getRequest(query);
    if (response.getStatusCode() == 200) {
      String jsonString = response.getBody();
      system.debug('jsonString ' + jsonString);
      compareRecords(jsonString);
      // insertRecords(jsonString);
    } else {
      System.debug(
        'Error occurred while getting records: ' + response.getBody()
      );
    }
  }

  //Compare source org and target org records
  private static void compareRecords(String jsonString) {
    sourceOrgRecords sourceRecords = getSourceOrgRecords(jsonString);
    Set<String> setOfSourceRecordIds = sourceRecords.setOfSourceRecordIds;
    List<SObject> listOfSourceRecords = sourceRecords.listOfSourceRecords;

    Map<String, sObject> mapOfMigrationIdTosObject = getTargetOrgRecords(
      setOfSourceRecordIds
    );

    Id recordId = setOfSourceRecordIds.iterator().next();
    String objectApiName = recordId.getSObjectType().getDescribe().getName();
    Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
    Set<String> setOfFieldNames = getFieldNames(objectApiName);
    List<sObject> listOfNewsObject = new List<sObject>();

    for (sObject sourceRecord : listOfSourceRecords) {
      String sourceRecordId = (String) sourceRecord.get('Id');
      if (mapOfMigrationIdTosObject.containsKey(sourceRecordId)) {
        sObject targetRecord = mapOfMigrationIdTosObject.get(sourceRecordId);
        system.debug('targetRecord ' + targetRecord);
        system.debug('sourceRecord ' + sourceRecord);
        if (targetRecord != null) {
          for (String fieldName : setOfFieldNames) {
            if (fieldName != 'Migration_Id__c' && fieldName != 'Id') {
              if (
                sourceRecord.getPopulatedFieldsAsMap().containsKey(fieldName) &&
                targetRecord.getPopulatedFieldsAsMap().containsKey(fieldName)
              ) {
                Object sourceValue = sourceRecord.get(fieldName);
                Object targetValue = targetRecord.get(fieldName);
                if (!isEqual(sourceValue, targetValue)) {
                  // Handle the difference in field values
                  System.debug(
                    'Difference found in field ' +
                      fieldName +
                      ' for source record with ID ' +
                      sourceRecord.Id
                  );
                  system.debug('sourceValue ' + sourceValue);
                  system.debug('targetValue ' + targetValue);
                  targetRecord.put(fieldName, sourceValue);
                } else {
                  system.debug(
                    'No difference found, for fieldname:- ' + fieldName
                  );
                }
              }
            }
          }
          listOfNewsObject.add(targetRecord);
          system.debug('listOfNewsObject ' + listOfNewsObject);
        }
      } else {
        system.debug('New record');
        sObject newRecord = objType.newSObject();
        newRecord.put('Migration_Id__c', sourceRecordId);
        Map<String, Object> mapOfSourceRecords = new Map<String, Object>();
        mapOfSourceRecords.putAll(sourceRecord.getPopulatedFieldsAsMap());
        system.debug('mapOfSourceRecords ' + mapOfSourceRecords);
        mapOfSourceRecords.remove('Id'); // Remove the 'Id' field from the map
        for (String fieldName : mapOfSourceRecords.keySet()) {
          object fieldValue = mapOfSourceRecords.get(fieldName);
          newRecord.put(fieldName, fieldValue);
        }
        system.debug('newRecord ' + newRecord);
        listOfNewsObject.add(newRecord);
      }
    }
    if (!listOfNewsObject.isEmpty()) {
      system.debug('listOfNewsObject ' + listOfNewsObject);
      insertRecords(listOfNewsObject);
    }
  }

  // compare source value and target value of each field
  private static Boolean isEqual(Object sourceValue, Object targetValue) {
    if (sourceValue == null && targetValue == null) {
      return true;
    } else if (sourceValue == null || targetValue == null) {
      return false;
    } else {
      return sourceValue.equals(targetValue);
    }
  }

  //Get name of fields to compare
  private static Set<String> getFieldNames(String objectApiName) {
    Set<String> setOfFieldNames = new Set<String>();
    Map<String, SObjectField> fieldsMap = Schema.getGlobalDescribe()
      .get(objectApiName)
      .getDescribe()
      .fields.getMap();
    for (SObjectField field : fieldsMap.values()) {
      String fieldName = field.getDescribe().getName();
      if (
        !field.getDescribe().isAutoNumber() &&
        !field.getDescribe().isCalculated() &&
        !fieldName.equals('Id') &&
        !fieldName.equals('IsDeleted') &&
        !fieldName.equals('MasterRecordId') &&
        !fieldName.equals('OwnerId') &&
        !fieldName.equals('LastModifiedById') &&
        !fieldName.equals('CreatedDate') &&
        !fieldName.equals('LastModifiedDate') &&
        !fieldName.equals('CreatedById') &&
        !fieldName.equals('SystemModstamp') &&
        !fieldName.equals('LastViewedDate') &&
        !fieldName.equals('LastReferencedDate') &&
        !fieldName.equals('PhotoUrl')
      ) {
        setOfFieldNames.add(fieldName);
      }
    }
    System.debug('setOfFieldNames: ' + JSON.serialize(setOfFieldNames));
    return setOfFieldNames;
  }

  // Get source Org Records as a sourceOrgRecords (wrapper) return type
  private static sourceOrgRecords getSourceOrgRecords(String jsonString) {
    SourceOrgRecords sourceOrgRecords = new SourceOrgRecords();
    sourceOrgRecords.setOfSourceRecordIds = new Set<String>();
    sourceOrgRecords.listOfSourceRecords = new List<SObject>();

    try {
      List<object> listOfRecords = (List<object>) JSON.deserializeUntyped(
        jsonString
      );

      List<sObject> listOfsObject = new List<sObject>();
      Set<String> setOfSourceRecordIds = new Set<String>();

      for (object sourceRecord : listOfRecords) {
        Map<String, Object> mapOfRecords = (Map<String, Object>) sourceRecord;
        String recordId = (String) mapOfRecords.get('Id');
        sourceOrgRecords.setOfSourceRecordIds.add(recordId);
        system.debug('recordId ' + recordId);
        Map<String, Object> mapOfAttributes = (Map<String, Object>) mapOfRecords.get(
          'attributes'
        );
        String objectName = mapOfAttributes.get('type').toString();
        mapOfRecords.remove('attributes');
        system.debug('objectName ' + objectName);
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        sObject record = objType.newSObject();

        for (String fieldName : mapOfRecords.keySet()) {
          object fieldValue = mapOfRecords.get(fieldName);
          record.put(fieldName, fieldValue);
        }
        sourceOrgRecords.listOfSourceRecords.add(record);
      }
    } catch (Exception ex) {
      system.debug(
        'Exception occured:- ' +
          ex.getMessage() +
          ' at line number:- ' +
          ex.getLineNumber()
      );
    }
    return sourceOrgRecords;
  }

  private static Map<String, sObject> getTargetOrgRecords(
    Set<String> setOfSourceRecordIds
  ) {
    String recordId = setOfSourceRecordIds.iterator().next();
    String objectName = getObjectApiName(recordId);
    Set<String> setOfFieldNames = getFieldNames(objectName);
    String joinedFields = String.join(new List<String>(setOfFieldNames), ', ');

    String targetOrgQuery =
      'SELECT ' +
      joinedFields +
      ' FROM ' +
      objectName +
      ' WHERE Migration_Id__c IN :setOfSourceRecordIds ' +
      ' ORDER BY CreatedDate DESC ';

    Map<String, sObject> mapOfMigrationIdTosObject = new Map<String, sObject>();
    for (sObject targetRecord : Database.query(targetOrgQuery)) {
      String migrationId = (String) targetRecord.get('Migration_Id__c');
      mapOfMigrationIdTosObject.put(migrationId, targetRecord);
    }
    return mapOfMigrationIdTosObject;
  }

  // Get the Json string and insert records
  private static String insertRecords(List<sObject> listOfsObject) {
    //private static String insertRecords(String jsonString) {
    // List<sObject> listOfsObject = getsObjectRecords(jsonString);

    try {
      Database.upsertResult[] upsertResult = Database.upsert(
        listOfsObject,
        false
      );

      List<String> successIds = new List<String>();
      List<String> errorMessages = new List<String>();

      for (Database.upsertResult result : upsertResult) {
        if (result.isSuccess()) {
          successIds.add(result.getId());
        } else {
          errorMessages.add(result.getErrors()[0].getMessage());
        }
      }
      system.debug('successIds size' + successIds.size());
      system.debug('errorMessages size ' + errorMessages.size());
      system.debug('errorMessages ' + errorMessages);

      return 'Records inserted successfully';
    } catch (Exception e) {
      return 'An error occurred while inserting the records';
    }
  }

  // Get the sObject records from JSON
  private static List<sObject> getsObjectRecords(String jsonString) {
    List<object> listOfRecords = (List<object>) JSON.deserializeUntyped(
      jsonString
    );
    List<sObject> listOfsObject = new List<sObject>();
    for (Object sourceRecord : listOfRecords) {
      Map<String, Object> mapOfRecords = (Map<String, Object>) sourceRecord;
      Map<String, Object> mapOfAttributes = (Map<String, Object>) mapOfRecords.get(
        'attributes'
      );
      String objectName = mapOfAttributes.get('type').toString();
      mapOfRecords.remove('attributes');

      Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
      if (objType <> null) {
        sObject record = objType.newSObject();
        // sObject newRecord = objType.newSObject();
        record.put('Migration_Id__c', mapOfRecords.get('Id'));
        mapOfRecords.remove('Id');
        for (String fieldName : mapOfRecords.keySet()) {
          object fieldValue = mapOfRecords.get(fieldName);
          SObjectType result = ((SObject) (Type.forName('Schema.' + objectName)
              .newInstance()))
            .getSObjectType();
          DescribeSObjectResult describe = result.getDescribe();
          //check data type of field
          Schema.DisplayType fieldType = describe.fields.getMap()
            .get(fieldName)
            .getDescribe()
            .getType();
          if (fieldType == Schema.DisplayType.REFERENCE && fieldValue != null) {
            String parentObjectApiName = getObjectApiName(fieldValue);
            sObject parentObject = (sObject) Type.forName(
                'Schema.' + parentObjectApiName
              )
              .newInstance();
            parentObject.put('Migration_Id__c', String.valueOf(fieldValue));
            record.putSObject(parentObjectApiName, parentObject);
          } else {
            record.put(fieldName, fieldValue);
          }
        }
        system.debug('listOfsObject ' + listOfsObject);
        listOfsObject.add(record);
      }
    }
    system.debug('listOfsObject size' + listOfsObject.size());
    return listOfsObject;
  }

  private static String getObjectApiName(object fieldValue) {
    Id recordId = (Id) fieldValue;
    SObjectType objectType = recordId.getSObjectType();
    return objectType.getDescribe().getName();
  }

  //   private static sObject getSobjectRecords(
  //     String fieldName,
  //     object fieldValue,
  //     String objectName
  //   ) {
  //     Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
  //     sObject sobjectRecord = objType.newSObject();

  //     SObjectType result = ((SObject) (Type.forName('Schema.' + objectName)
  //         .newInstance()))
  //       .getSObjectType();
  //     DescribeSObjectResult describe = result.getDescribe();
  //     //check data type of field
  //     Schema.DisplayType fieldType = describe.fields.getMap()
  //       .get(fieldName)
  //       .getDescribe()
  //       .getType();
  //     if (fieldType == Schema.DisplayType.REFERENCE && fieldValue != null) {
  //       Id objectId = (Id) fieldValue;
  //       SObjectType objectType = objectId.getSObjectType();
  //       String parentObjectApiName = objectType.getDescribe().getName();
  //       sObject parentObject = (sObject) Type.forName(
  //           'Schema.' + parentObjectApiName
  //         )
  //         .newInstance();
  //       parentObject.put('Migration_Id__c', String.valueOf(fieldValue));
  //       sobjectRecord.putSObject(parentObjectApiName, parentObject);
  //     } else {
  //       sobjectRecord.put(fieldName, fieldValue);
  //     }
  //     return sobjectRecord;
  //   }

  //Temporary static query for get the records from source org
  private static String getStringQuery(String objectName) {
    String query;
    if (String.isNotBlank(objectName) && objectName == 'Account') {
      query =
        'SELECT Name, AccountNumber, AnnualRevenue, Industry ' +
        'FROM ' +
        objectName +
        ' ORDER By CreatedDate Desc ' +
        ' LIMIT 4';
    }

    if (String.isNotBlank(objectName) && objectName == 'Contact') {
      query =
        'SELECT FirstName, LastName, AccountId, Description, Department ' +
        'FROM ' +
        objectName +
        ' ORDER By CreatedDate Desc ' +
        'LIMIT 10';
    }
    if (String.isNotBlank(query)) {
      return query;
    }

    return null;
  }

  public class SourceOrgRecords {
    public Set<String> setOfSourceRecordIds;
    public List<SObject> listOfSourceRecords;
  }
  //Temporary static query for get the records from source org (those object have look-up field)
  //   private static String getChildObjectQuery(String objectName) {
  //     String query;
  //     if (String.isNotBlank(objectName)) {
  //       query =
  //         'SELECT FirstName, LastName, AccountId, Description, Department ' +
  //         'FROM ' +
  //         objectName +
  //         ' ORDER By CreatedDate Desc ' +
  //         'LIMIT 10';
  //     }
  //     if (String.isNotBlank(query)) {
  //       return query;
  //     }
  //     return null;
  //   }
}