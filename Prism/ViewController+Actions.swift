import Cocoa;

extension ViewController {    
    func showcase(category: Application.Category) {
        switch category {
        case .dock:
            preferredApplicationsInCurrentCategory = nil;
            applicationsInCurrentCategory = [];
            checkDock: for dockApplicationIdentifier in dockApplicationIdentifiers {
                for application in applications {
                    if application.identifier == dockApplicationIdentifier {
                        applicationsInCurrentCategory!.append(application);
                        continue checkDock;
                    }
                }
            }
        case .any:
            applicationsInCurrentCategory = applications;
            preferredApplicationsInCurrentCategory = applications.filter {application -> Bool in
                !application.categories.contains(.deprecating)
            };
        default:
            preferredApplicationsInCurrentCategory = nil;
            applicationsInCurrentCategory = applications.filter {application -> Bool in
                application.categories.contains(category);
            };
        }
        
        if isSearching && searchField != nil {
            onSearch(searchField!);
        } else {
            showcase(applications: nil);
        }
    }
    
    func showcase(applications given: [Application]?) {
        if showsCustomizedOnly == false {
            showcaseViewController.applications = given ?? preferredApplicationsInCurrentCategory ?? applicationsInCurrentCategory ?? applications;
            showcaseViewController.tableView.reloadData();
            return;
        }
        
        let applicationSource = given ?? applicationsInCurrentCategory ?? applications;
        let filterResult = applicationSource.filter {application -> Bool in
            if Accent.systemAccent == .unset {
                return application.accent != .unset && application.accent != .unknown;
            }
            return application.accent != .unset;
        }
        showcaseViewController.applications = filterResult;
        showcaseViewController.tableView.reloadData();
    }
    
    func searchFor(_ inputString: String) {
        if inputString == "" {
            showcase(applications: nil);
            isSearching = false;
            return;
        }
        
        isSearching = true;
        let keywords = inputString.lowercased();
        
        let split = keywords.split(separator: " ");
        var searchResults = [Application]();
        
        for application in applicationsInCurrentCategory ?? applications {
            let name = application.name.lowercased();
            let displayName = application.displayName.lowercased();
            let domain = application.identifier.domain.lowercased();
            
            if (
                domain.contains(keywords) ||
                name.contains(keywords) ||
                displayName.contains(keywords)
            ) {
                searchResults.append(application);
                continue;
            }
            
            var matchesAllWords = true;
            for word in split {
                if (
                    !name.contains(word) &&
                    !displayName.contains(word)
                ) {
                    matchesAllWords = false;
                    break;
                }
            }
            if matchesAllWords {
                searchResults.append(application);
                continue;
            }
        }
        
        showcase(applications: searchResults);
    }
    
    @objc func onSearch(_ searchField: NSSearchField) {
        if showsCustomizedOnly {
            showAll(nil);
        }
        
        searchFor(searchField.stringValue);
    }
    
    @objc func onSegmented(_ segmentedControl: NSSegmentedControl) {
        if segmentedControl.selectedSegment == 1 {
            showCustomized(setSegmentedControl: false, clearSearchField: true);
        } else {
            showAll(setSegmentedControl: false, clearSearchField: true);
        }
    }
    
    func showAll(setSegmentedControl: Bool, clearSearchField: Bool) {
        if clearSearchField {
            searchField?.stringValue = "";
        }
        if setSegmentedControl {
            segmentedControl?.selectedSegment = 0;
        }
        showsCustomizedOnly = false;
        showAllMenuItem?.state = .on;
        showCustomizedMenuItem?.state = .off;
        menubarShowAllMenuItem?.state = .on;
        menubarShowCustomizedMenuItem?.state = .off;
        showcase(applications: nil);
    }
    
    func showCustomized(setSegmentedControl: Bool, clearSearchField: Bool) {
        if isSearching || clearSearchField {
            searchField?.stringValue = "";
            view.window?.makeFirstResponder(nil);
        }
        if setSegmentedControl {
            segmentedControl?.selectedSegment = 1;
        }
        showsCustomizedOnly = true;
        showAllMenuItem?.state = .off;
        showCustomizedMenuItem?.state = .on;
        menubarShowAllMenuItem?.state = .off;
        menubarShowCustomizedMenuItem?.state = .on;
        showcase(applications: nil);
    }
    
    @IBAction func showAll(_ sender: Any?) {
        showAll(setSegmentedControl: true, clearSearchField: false);
    }
    
    @IBAction func showCustomized(_ sender: Any?) {
        showCustomized(setSegmentedControl: true, clearSearchField: false);
    }
    
    @IBAction func doSearch(_ sender: Any) {
        view.window?.toolbar?.isVisible = true;
        searchField?.becomeFirstResponder();
    }
    
    @objc func setAccent(_ popUpButton: AccentPopUpButton) {
        if popUpButton.indexOfSelectedItem == popUpButton.previousIndexOfSelectedItem {
            return;
        }
        
        let selectedAccent = Accent(rawValue: popUpButton.selectedItem!.tag)!;
        let application = popUpButton.application!;
        
        if application.identifier.domain == Bundle.main.bundleIdentifier {
            return;
        }
        
        startProgressIndicating();
        
        secondaryQueue.async {
            if !Accent.set(selectedAccent, for: application) {
                DispatchQueue.main.sync {
                    popUpButton.selectItem(at: popUpButton.previousIndexOfSelectedItem);
                    self.failedAlert.messageText = String(format: "failed-alert-title".localized, application.displayName);
                    self.failedAlert.beginSheetModal(for: self.view.window!) { (modalResponse) in
                        if modalResponse == .alertSecondButtonReturn {
                            let pasteboard = NSPasteboard.general;
                            pasteboard.clearContents();
                            pasteboard.setString(application.identifier.domain, forType: .string);
                        }
                    };
                    self.stopProgressIndicating();
                }
                return;
            }
            
            popUpButton.application!.accent = selectedAccent;
            if !self.shouldRelaunchApplications {
                DispatchQueue.main.sync(execute: self.stopProgressIndicating);
                return;
            }
            
            self.attemptTerminateApplicationAfterSettingAccent(for: application);
        }
    }
    
    func attemptTerminateApplicationAfterSettingAccent(for application: Application) {
        var runningApplication: NSRunningApplication?;
        for running in NSWorkspace.shared.runningApplications {
            if running.bundleIdentifier == application.identifier.domain {
                runningApplication = running;
                break;
            }
        }
        if runningApplication == nil {
            DispatchQueue.main.sync(execute: self.stopProgressIndicating);
            return;
        }
        
        let signalSentDate = Date();
        runningApplication!.terminate();
        
        func checkTerminated() {
            if runningApplication!.isTerminated {
                _ = try? NSWorkspace.shared.launchApplication(at: URL(fileURLWithPath: application.identifier.path), options: NSWorkspace.LaunchOptions.default, configuration: [:]);
                DispatchQueue.main.sync(execute: self.stopProgressIndicating);
                return;
            }
            
            if Date().timeIntervalSince(signalSentDate) > self.waitingSecondsAfterAttemptingQuit {
                DispatchQueue.main.sync {
                    self.cannotQuitAlert.messageText = String(format: "cannot-quit-alert-title".localized, application.displayName);
                    self.cannotQuitAlert.beginSheetModal(for: self.view.window!) {_ in
                        self.stopProgressIndicating();
                    }
                }
                return;
            }
            self.secondaryQueue.async(execute: checkTerminated);
        }
        
        self.secondaryQueue.async(execute: checkTerminated);
    }
    
    @objc func onShouldRelaunchCheckboxToggle(_ checkbox: NSButton) {
        shouldRelaunchApplications = checkbox.state == .on;
        UserDefaults.standard.set(shouldRelaunchApplications, forKey: "shouldRelaunchApplications");
    }
}
