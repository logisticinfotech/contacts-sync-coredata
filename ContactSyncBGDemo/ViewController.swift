//
//  ViewController.swift
//  ContactSyncBGDemo
//
//  Created by Vishal on 05/03/19.
//  Copyright © 2019 Vishal. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var arrAllContact:[Contact]!
    var filteredContact:[Contact]!
    var searchActive : Bool = false

    @IBOutlet weak var searchbar: UISearchBar!
    @IBOutlet weak var tblContactList: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "LI Contact sync "
        searchbar.showsCancelButton = false
        searchbar.delegate = self
        self.arrAllContact =  (CoreDataManager.sharedInstance.getObjectsforEntity(strEntity: "Contact", ShortBy: "firstName", isAscending: true, predicate: nil, groupBy: "", taskContext: CoreDataManager.sharedInstance.managedObjectContext) as! NSArray).mutableCopy() as? [Contact]
        if((self.arrAllContact) != nil){
            self.tblContactList.reloadData()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(contactUpdate), name: NSNotification.Name(rawValue: "ContactSync"), object: nil)
        // Do any additional setup after loading the view, typically from a nib.
    }
    @objc func contactUpdate() -> Void {
        print("Operation End Time-->\(Date())")
        self.arrAllContact =  (CoreDataManager.sharedInstance.getObjectsforEntity(strEntity: "Contact", ShortBy: "firstName", isAscending: true, predicate: nil, groupBy: "", taskContext: CoreDataManager.sharedInstance.managedObjectContext) as! NSArray).mutableCopy() as? [Contact]
        
        DispatchQueue.main.async {
            if(self.searchActive && self.searchbar.text != ""){
                self.searchBar(self.searchbar, textDidChange: self.searchbar.text ?? "")
            }
            self.tblContactList.reloadData()
        }        
        print("Tableview refresh Time-->\(Date())")

        print("Contact update")
    }
}
extension ViewController: UITableViewDelegate,UITableViewDataSource,UISearchBarDelegate{
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchActive{
            return (filteredContact != nil) ? filteredContact.count : 0
        }else{
            return (arrAllContact != nil) ? arrAllContact.count : 0
        }
        
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactCell
        var objContact: Contact?
        if searchActive{
            objContact = filteredContact[indexPath.row]
        }else{
            objContact = arrAllContact[indexPath.row]
        }
        
        cell.lblContactName.text = (objContact?.firstName ?? "") + " " + (objContact?.lastName ??  "")
        cell.lblContactNumber.text = objContact?.mobileNumber
        return cell
        
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if(searchBar.text != ""){
            searchActive = true
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false;
        searchBar.text = nil
        searchBar.resignFirstResponder()
        tblContactList.resignFirstResponder()
        self.searchbar.showsCancelButton = false
        tblContactList.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
                self.searchbar.showsCancelButton = true
        if(searchText != ""){
            self.searchActive = true;
            if((self.arrAllContact) != nil){
                self.filteredContact = self.arrAllContact.filter(){
                    return (($0 as Contact).firstName?.contains(searchText))!
                }
            }
            self.tblContactList.reloadData()
        }
        

        
        
    }

    
}

