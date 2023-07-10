/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 07-06-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class CalloutServices {
  /**
   * @description:- Make the callout to source org to get the data
   * @ return type:- HttpResponse
   */
  public static HttpResponse getRequest(String query) {
    HttpRequest req = new HttpRequest();
    // req.setEndpoint('callout:Salesforce_Org/services/data/v49.0?q=' + query);
    req.setEndpoint(
      'callout:Salesforce_Org/services/apexrest/getRecords/?q=' +
      EncodingUtil.urlEncode(query, 'UTF-8')
    );
    req.setMethod('GET');
    Http http = new Http();
    HTTPResponse response = http.send(req);
    System.debug(' response Status :: ' + response);
    System.debug(' response :: ' + response.getBody());
    return response;
  }
}