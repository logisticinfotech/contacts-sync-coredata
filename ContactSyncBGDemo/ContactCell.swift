
//
//  ContactCell.swift
//  ContactSyncBGDemo
//
//  Created by Vishal on 13/03/19.
//  Copyright © 2019 Vishal. All rights reserved.
//

import UIKit

class ContactCell: UITableViewCell {

    @IBOutlet weak var lblContactNumber: UILabel!
    @IBOutlet weak var lblContactName: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
