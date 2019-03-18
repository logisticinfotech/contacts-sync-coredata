//
//  ContactUtility.swift
//  ContactSyncBGDemo
//
//  Created by Vishal on 07/03/19.
//  Copyright © 2019 Vishal. All rights reserved.
//

import Foundation
import UIKit
import Contacts
import ContactsUI
import libPhoneNumber_iOS
import CoreData


class ContactUtility: NSObject {
    
    //MARK: - Class Variables
    //MARK: -
    
    
    let contactStore = CNContactStore()
    let arrContactsDicts = NSMutableArray()
    
    static let sharedInstance:ContactUtility = {
        let instance = ContactUtility()
        return instance
    }()
    
    func getContact() -> [CNContact] {
        print("Start Time-->\(Date())")
        var results:[CNContact] = []
        let keyToContactFetch = [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactMiddleNameKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor,CNContactPhoneNumbersKey as CNKeyDescriptor]
        
        let fetchRequest = CNContactFetchRequest(keysToFetch: keyToContactFetch)
        fetchRequest.sortOrder = CNContactSortOrder.userDefault
        do{
            try self.contactStore.enumerateContacts(with: fetchRequest, usingBlock: { (contact, stop) in
                print(contact.phoneNumbers.first?.value ?? "no")
                results.append(contact)
            })
        }
        catch let error as NSError {
            print(error.localizedDescription)
        }
        print("Contact Fetch End Time-->\(Date())")
        return results

    }   
    
    /// The method request asks for permission to access contacts
    ///
    /// - Parameter completionHandler: This closure returns a boolean when whole process is complete
    
    func requestedForAccess(complitionHandler:@escaping ( _ accessGranted:Bool)->Void){
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)
        
        switch authorizationStatus {
        case .authorized:
            complitionHandler(true)
        case .notDetermined,.denied:
            self.contactStore.requestAccess(for: CNEntityType.contacts  ) { (access, accessError) in
                if access{
                    complitionHandler(access)
                }else{
                    if authorizationStatus == .denied{
                        let message="Allow access to contacts to this app using settings app"
                        DispatchQueue.main.async{
                            print(message)
                        }
                    }
                }
            }
        default:
            complitionHandler(false)
        }
    }
    
    func syncPhoneBookContactsWithLocalDB(completionHandler:@escaping (_ success:Bool) -> ()){
        if(appDelegate.isContactSyncInProgress == false){
            appDelegate.isContactSyncInProgress = true
            self.createDictOfContactList { (arrDictContactList) in
                print("arrDictContactList--> \(arrDictContactList)")
                DispatchQueue.global(qos: .background).async {
                    let arrContactList =  CoreDataManager.sharedInstance.getObjectsforEntity(strEntity: "Contact", ShortBy: "", isAscending: false, predicate: nil, groupBy: "", taskContext: CoreDataManager.sharedInstance.bGManagedObjectContext) as! NSArray
                    
                    if arrContactList.count > 0{
                        //Check for require update contact in db
                        let tempArrContactDict = self.arrContactsDicts
                        for contact in arrContactList{
                            let tempContactDb = contact as! Contact
                            let mobileNumber = tempContactDb.mobileNumber
                            if(mobileNumber != ""){
                                let arrFilterContact = self.arrContactsDicts.filter({($0 as! ContactBean).mobileNumber! == mobileNumber!})
                                if arrFilterContact.count > 0{
                                    let filterdContact = arrFilterContact.first as! ContactBean
                                    
                                    if(filterdContact.firstName != tempContactDb.firstName || filterdContact.lastName != tempContactDb.lastName || filterdContact.email != tempContactDb.email  ){
                                        
                                        tempContactDb.firstName = filterdContact.firstName
                                        tempContactDb.lastName = filterdContact.lastName
                                        tempContactDb.email = filterdContact.email
                                        sharedCoreDataManager.saveContextInBG()
                                        print("Contact is Updated from db --> \(String(describing: tempContactDb.mobileNumber))")
                                        //Update contact if it was updated in contact
                                    }
                                    tempArrContactDict.remove(arrFilterContact.first as Any)
                                    
                                }else{
                                    
                                    //                                This contact is not available in newContact dict so it means this contact is deleted in contact directory so we need to delete from out data base.
                                    print("Contact is deleted from db --> \(String(describing: tempContactDb.mobileNumber))")
                                    sharedCoreDataManager.deleteObject(object: tempContactDb, taskContext: CoreDataManager.sharedInstance.bGManagedObjectContext)
                                    
                                    //Delete this contact from db
                                }
                            }
                        }
                        
                        if(tempArrContactDict.count > 0)
                        {
                            //After sync new contact list with local db there is still contact is avalilabe in contact dict so it means there is newly insertad contact so insert new contact in the local data base
                            print("There is some new contact added")
                            self.saveNewContactInDb(dict:tempArrContactDict,completionHandler: { (success) in
                                completionHandler(true)
                            })
                        }
                        else{
                            print("There is no any new contact added")
                            completionHandler(true)
                        }
                    }else{
                        //Save all new contact in db
                        print("Fresh contact list add")
                        self.saveNewContactInDb(dict: self.arrContactsDicts, completionHandler: { (success) in
                            completionHandler(true)
                        })
                    }
                }
                
                //Now check in core db
                //IF contact > 0 --> Store all contact in db
                //Else if check contact is available in contact list of db if yes then check it was updated than it will be update in db and delete from contact dict
                //else that contact is new contact and store in db and update in the coredata.
            }
        }
    }
    
    func saveNewContactInDb(dict:NSMutableArray, completionHandler:@escaping (_ success:Bool) -> ()) -> Void {
        DispatchQueue.global(qos: .background).async {
            
            for newContact in dict{
                let tempContact = newContact as! ContactBean
                
                let objContact = (CoreDataManager.sharedInstance.createObjectForEntity(entityName: "Contact", taskContext: sharedCoreDataManager.bGManagedObjectContext) ) as! Contact
                    
                objContact.firstName = tempContact.firstName!
                objContact.lastName = tempContact.lastName!
                objContact.email = tempContact.email!
                objContact.mobileNumber = tempContact.mobileNumber!
                sharedCoreDataManager.saveContextInBG()
//                sharedCoreDataManager.saveContext()
//                self.arrContactsDicts.remove(newContact)
            }
                completionHandler(true)
        }
    }
    
    func createDictOfContactList(compilationClosure: @escaping (_ arrContectDict:NSMutableArray)->()){
        self.arrContactsDicts.removeAllObjects()
        print("Create dict-->\(Date())")
        DispatchQueue.global(qos: .background).async {
            self.requestedForAccess { (accessGranted) in
                if(accessGranted){
                    for contact in self.getContact()
                    {
                        for tempContact:CNLabeledValue in contact.phoneNumbers
                        {
                            if contact.givenName.lowercased() == "spam" || contact.givenName.lowercased() == "identified as spam" {
                                continue
                            }
                            
                            var emailAddress = ""
                            
                            if (contact.emailAddresses as NSArray).count != 0{
                                emailAddress = (contact.emailAddresses.first!).value as String
                            }
                            self.getFinalNumber(tempContact, compilationClosure: { (finalNumber) in
                                
                                if (finalNumber != ""){
//
//                                    print("Mobile number -> \(finalNumber)")
//                                    print("First name -> \(contact.givenName)")
//                                    print("Father name -> \(contact.middleName)")
//                                    print("Last Name -> \(contact.familyName)")
//                                    print("email -> \(emailAddress)")
                                    
                                    let dict = ContactBean.init(firstName: contact.givenName, lastName: contact.familyName, mobileNumber: finalNumber, email: emailAddress)
                                    self.arrContactsDicts.add(dict)

                                }
                            })
                            
                        }
                    }
                    print("End Create dict-->\(Date())")
                    compilationClosure(self.arrContactsDicts)
                }else{
                    compilationClosure([])
                }
                
            }
        }
        
    }
    func getFinalNumber(_ phoneNumber:CNLabeledValue<CNPhoneNumber>, compilationClosure: @escaping (_ finalNumber:String)->()){
        
        var finalPhoneNumber = self.DigitsForPhone(phoneNumber)
        print("Final Phone number first-->\(finalPhoneNumber)")
        
        let strCountryCode = self.CountryCodeForPhoneNumber(finalPhoneNumber)
        
        print("strCountryCode first-->\(strCountryCode)")
        
        if strCountryCode == ""{
            if let countryCode = (Locale.current as NSLocale).object(forKey: .countryCode) as? String {
                print(countryCode)
                
                let countryCodeDigit = "+" + self.getCountryCallingCode(countryRegionCode: countryCode)
                print("strCountryCode sec-->\(countryCodeDigit)")
                finalPhoneNumber = countryCodeDigit + finalPhoneNumber
                print("finalPhoneNumber sec-->\(finalPhoneNumber)")
            }
        }
        print("strCountrCode-->\(strCountryCode)")
        print("Final Phone number -->\(finalPhoneNumber)")
        
        compilationClosure(finalPhoneNumber)
    }

    
    func getCountryCallingCode(countryRegionCode:String)->String{
        
        let prefixCodes = ["AF": "93", "AE": "971", "AL": "355", "AN": "599", "AS":"1", "AD": "376", "AO": "244", "AI": "1", "AG":"1", "AR": "54","AM": "374", "AW": "297", "AU":"61", "AT": "43","AZ": "994", "BS": "1", "BH":"973", "BF": "226","BI": "257", "BD": "880", "BB": "1", "BY": "375", "BE":"32","BZ": "501", "BJ": "229", "BM": "1", "BT":"975", "BA": "387", "BW": "267", "BR": "55", "BG": "359", "BO": "591", "BL": "590", "BN": "673", "CC": "61", "CD":"243","CI": "225", "KH":"855", "CM": "237", "CA": "1", "CV": "238", "KY":"345", "CF":"236", "CH": "41", "CL": "56", "CN":"86","CX": "61", "CO": "57", "KM": "269", "CG":"242", "CK": "682", "CR": "506", "CU":"53", "CY":"537","CZ": "420", "DE": "49", "DK": "45", "DJ":"253", "DM": "1", "DO": "1", "DZ": "213", "EC": "593", "EG":"20", "ER": "291", "EE":"372","ES": "34", "ET": "251", "FM": "691", "FK": "500", "FO": "298", "FJ": "679", "FI":"358", "FR": "33", "GB":"44", "GF": "594", "GA":"241", "GS": "500", "GM":"220", "GE":"995","GH":"233", "GI": "350", "GQ": "240", "GR": "30", "GG": "44", "GL": "299", "GD":"1", "GP": "590", "GU": "1", "GT": "502", "GN":"224","GW": "245", "GY": "595", "HT": "509", "HR": "385", "HN":"504", "HU": "36", "HK": "852", "IR": "98", "IM": "44", "IL": "972", "IO":"246", "IS": "354", "IN": "91", "ID":"62", "IQ":"964", "IE": "353","IT":"39", "JM":"1", "JP": "81", "JO": "962", "JE":"44", "KP": "850", "KR": "82","KZ":"77", "KE": "254", "KI": "686", "KW": "965", "KG":"996","KN":"1", "LC": "1", "LV": "371", "LB": "961", "LK":"94", "LS": "266", "LR":"231", "LI": "423", "LT": "370", "LU": "352", "LA": "856", "LY":"218", "MO": "853", "MK": "389", "MG":"261", "MW": "265", "MY": "60","MV": "960", "ML":"223", "MT": "356", "MH": "692", "MQ": "596", "MR":"222", "MU": "230", "MX": "52","MC": "377", "MN": "976", "ME": "382", "MP": "1", "MS": "1", "MA":"212", "MM": "95", "MF": "590", "MD":"373", "MZ": "258", "NA":"264", "NR":"674", "NP":"977", "NL": "31","NC": "687", "NZ":"64", "NI": "505", "NE": "227", "NG": "234", "NU":"683", "NF": "672", "NO": "47","OM": "968", "PK": "92", "PM": "508", "PW": "680", "PF": "689", "PA": "507", "PG":"675", "PY": "595", "PE": "51", "PH": "63", "PL":"48", "PN": "872","PT": "351", "PR": "1","PS": "970", "QA": "974", "RO":"40", "RE":"262", "RS": "381", "RU": "7", "RW": "250", "SM": "378", "SA":"966", "SN": "221", "SC": "248", "SL":"232","SG": "65", "SK": "421", "SI": "386", "SB":"677", "SH": "290", "SD": "249", "SR": "597","SZ": "268", "SE":"46", "SV": "503", "ST": "239","SO": "252", "SJ": "47", "SY":"963", "TW": "886", "TZ": "255", "TL": "670", "TD": "235", "TJ": "992", "TH": "66", "TG":"228", "TK": "690", "TO": "676", "TT": "1", "TN":"216","TR": "90", "TM": "993", "TC": "1", "TV":"688", "UG": "256", "UA": "380", "US": "1", "UY": "598","UZ": "998", "VA":"379", "VE":"58", "VN": "84", "VG": "1", "VI": "1","VC":"1", "VU":"678", "WS": "685", "WF": "681", "YE": "967", "YT": "262","ZA": "27" , "ZM": "260", "ZW":"263"]
        let countryDialingCode = prefixCodes[countryRegionCode]
        return countryDialingCode!
        
    }
    
    func CountryCodeForPhoneNumber(_ phoneNumber:String) -> String{
        
        do {
            let phNumber = try NBPhoneNumberUtil.sharedInstance().parse(phoneNumber, defaultRegion: "") as NBPhoneNumber
            return "+\(phNumber.countryCode!)"
            
        } catch {
            return ""
        }
    }
    

    /// The method gives plain numbers (without masking) from Phone Book phone number
    ///
    /// - Parameter phoneNumber: Phone Book contat Phone number
    /// - Returns: phone number without masking
    
    func DigitsForPhone(_ phoneNumber:CNLabeledValue<CNPhoneNumber>) -> String{
        
        var strPhoneNumber = ((phoneNumber.value as CNPhoneNumber).value(forKey: "digits")! as! String)
        if strPhoneNumber.first == "0"{
            strPhoneNumber = strPhoneNumber.substring(from: strPhoneNumber.index(strPhoneNumber.startIndex, offsetBy: 1))
        }
        return strPhoneNumber
    }
    func isValidMobile(_ mobile: String) -> Bool {
        
        let PHONE_REGEX = "^\\+\\d{8,17}"
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", PHONE_REGEX)
        let result =  phoneTest.evaluate(with: mobile)
        return result
    }

}

