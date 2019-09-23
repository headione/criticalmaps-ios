//
//  ManageFriendsViewController.swift
//  CriticalMaps
//
//  Created by Leonard Thomas on 22.09.19.
//  Copyright © 2019 Pokus Labs. All rights reserved.
//

import UIKit

class ManageFriendsViewController: UIViewController, IBConstructable, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet var tableView: UITableView!
    private var dataStore: DataStore!

    enum Section: Int, CaseIterable {
        case friends
        case settings
    }

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        super.init(nibName: ManageFriendsViewController.nibName, bundle: ManageFriendsViewController.bundle)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationBar()
        tableView.register(cellType: FriendTableViewCell.self)
        tableView.register(cellType: FriendSettingsTableViewCell.self)
        tableView.register(viewType: SettingsTableSectionHeader.self)
    }

    private func configureNavigationBar() {
        title = "Friends"
        let addFriendBarButtonItem = UIBarButtonItem(title: "Add Friend", style: .plain, target: self, action: #selector(addFriendButtonTapped))
        navigationItem.rightBarButtonItem = addFriendBarButtonItem
    }

    @objc func addFriendButtonTapped() {
        let viewController = FollowFriendsViewController(name: dataStore.userName)
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func update(name: String) {
        dataStore.userName = name
    }

    func numberOfSections(in _: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .friends:
            return dataStore.friends.count
        case .settings:
            return 1
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section)! {
        case .friends:
            return nil
        case .settings:
            let header = tableView.dequeueReusableHeaderFooterView(ofType: SettingsTableSectionHeader.self)
            header.titleLabel.text = "Settings"
            return header
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section)! {
        case .friends:
            return 0.0
        case .settings:
            return 42.0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .friends:
            let cell = tableView.dequeueReusableCell(ofType: FriendTableViewCell.self, for: indexPath)
            let friend = dataStore.friends[indexPath.row]
            // isOnline isn't supported yet
            cell.configure(name: friend.name, isOnline: false)
            return cell
        case .settings:
            let cell = tableView.dequeueReusableCell(ofType: FriendSettingsTableViewCell.self, for: indexPath)
            cell.configure(name: dataStore.userName, nameChanged: update)
            return cell
        }
    }
}
