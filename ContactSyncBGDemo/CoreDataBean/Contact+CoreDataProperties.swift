//
//  Contact+CoreDataProperties.swift
//  ContactSyncBGDemo
//
//  Created by Vishal on 08/03/19.
//  Copyright © 2019 Vishal. All rights reserved.
//
//

import Foundation
import CoreData


extension Contact {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Contact> {
        return NSFetchRequest<Contact>(entityName: "Contact")
    }

    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
    @NSManaged public var mobileNumber: String?    
    @NSManaged public var email: String?
    
}
