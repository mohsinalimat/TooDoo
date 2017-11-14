//
//  ToDoOverviewViewController.swift
//  TooDoo
//
//  Created by Cali Castle  on 10/15/17.
//  Copyright © 2017 Cali Castle . All rights reserved.
//

import UIKit
import Haptica
import Hokusai
import CoreData
import ViewAnimator

class ToDoOverviewViewController: UIViewController {

    /// Storyboard identifier
    
    static let identifier = "ToDoOverview"
    
    // MARK: - Properties
    
    /// Interface builder outlets
    @IBOutlet var userAvatarContainerView: DesignableView!
    @IBOutlet var userAvatarImageView: UIImageView!
    @IBOutlet var greetingLabel: UILabel!
    @IBOutlet var greetingWithTimeLabel: UILabel!
    @IBOutlet var todoMessageLabel: UILabel!
    @IBOutlet var todosCollectionView: UICollectionView!
    
    /// Storyboard segues.
    ///
    /// - ShowCategory: Add/Edit a category
    
    private enum Segue: String {
        case ShowCategory = "ShowCategory"
    }
    
    /// Navigation ttems enum.
    ///
    /// - Menu: Menu bar button
    /// - Search: Search bar button
    /// - Add: Add bar button
    
    private enum NavigationItem: Int {
        case Menu
        case Search
        case Add
    }
    
    /// Dependency Injection for Managed Object Context
    
    var managedObjectContext: NSManagedObjectContext?
    
    /// Fetched results controller for Core Data.
    
    private lazy var fetchedResultsController: NSFetchedResultsController<Category> = {
        // Create fetch request
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        // Configure fetch request sort method
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Category.order), ascending: true), NSSortDescriptor(key: #keyPath(Category.createdAt), ascending: true)]
        
        // Create controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    /// Has categories or not.
    
    private var hasCategories: Bool {
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else { return false }
        
        return fetchedObjects.count > 0
    }
    
    /// Current related category index.
    
    private var currentRelatedCategoryIndex: IndexPath?
    
    /// Long press gesture recognizer for category re-order.
    
    lazy var longPressForReorderCategoryGesture: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(categoryLongPressed))
        
        return recognizer
    }()
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        configureUserSettings()
        fetchCategories()
        
        startAnimations()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        animateTodoCollectionView()
    }
    
    /// Fetch categories from core data.
    
    private func fetchCategories() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            /// FIXME: Handle error
            print("Unable to Execute Fetch Request")
            print("\(error), \(error.localizedDescription)")
        }
    }
    
    /// Set up views properties.
    
    fileprivate func setupViews() {
        setupTimeLabel()
        setupMessageLabel()
        setupTodosCollectionView()
    }
    
    /// Set up greetingWithTimeLabel.
    
    fileprivate func setupTimeLabel() {
        let now = Date()
        let todayCompnents = Calendar.current.dateComponents([.hour], from: now)
        
        // FIXME: Localization
        switch todayCompnents.hour! {
        case 5..<12:
            // Morning
            greetingWithTimeLabel.text = "Good morning ☀️"
            greetingWithTimeLabel.textColor = UIColor(hexString: "F8E71C")
        case 12..<19:
            // Afternoon
            greetingWithTimeLabel.text = "Good afternoon ☕️"
            greetingWithTimeLabel.textColor = UIColor(hexString: "F5A623")
        default:
            // Evening
            greetingWithTimeLabel.text = "Good evening 🌙"
            greetingWithTimeLabel.textColor = UIColor(hexString: "E8A278")
        }
    }
    
    /// Set up todoMessageLabel.
    
    fileprivate func setupMessageLabel() {
        let dateFormatter = DateFormatter()
        // Format date to 'Monday, Nov 6'
        dateFormatter.dateFormat = "EEEE, MMM d"
        
        // FIXME: Localization
        todoMessageLabel.text = "Today is \(dateFormatter.string(from: Date())).\nNo todos due today."
    }
    
    /// Set up todos collection view properties.
    
    fileprivate func setupTodosCollectionView() {
        (todosCollectionView.collectionViewLayout as! UICollectionViewFlowLayout).itemSize = CGSize(width: todosCollectionView.bounds.width * 0.8, height: todosCollectionView.bounds.height)
        todosCollectionView.decelerationRate = UIScrollViewDecelerationRateFast
        todosCollectionView.addGestureRecognizer(longPressForReorderCategoryGesture)
    }
    
    /// Configure user information to the designated views.
    
    fileprivate func configureUserSettings() {
        guard let userName = UserDefaultManager.string(forKey: .UserName) else { return }
        guard let userAvatar = UserDefaultManager.image(forKey: .UserAvatar) else { return }
        
        userAvatarImageView.image = userAvatar
        greetingLabel.text = greetingLabel.text?.replacingOccurrences(of: "%name%", with: userName).localizedCapitalized
    }
    
    /// Light status bar.
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    /// Auto hide home indicator
    
    @available(iOS 11, *)
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return true
    }

    // MARK: - Handle Interface Builder Actions.
    
    @IBAction func navigationItemDidTap(_ sender: UIBarButtonItem) {
        /// FIXME
        switch sender.tag {
        case NavigationItem.Menu.rawValue:
            print("Menu!")
        case NavigationItem.Search.rawValue:
            print("Search!")
        default:
            showAddNewItem()
        }
    }
    
    /// Show action sheet for adding a new item.
    
    fileprivate func showAddNewItem() {
        // Play click sound and haptic
        SoundManager.play(soundEffect: .Click)
        Haptic.impact(.light).generate()
        
        // FIXME: Localization
        let actionSheet = Hokusai(headline: "Create a")
        
        actionSheet.colors = HOKColors(backGroundColor: UIColor.flatBlack(), buttonColor: UIColor.flatLime(), cancelButtonColor: UIColor(hexString: "444444"), fontColor: .white)
        actionSheet.cancelButtonTitle = "Cancel"

        let _ = actionSheet.addButton("New Todo", target: self, selector: #selector(showAddTodo))
        let _ = actionSheet.addButton("New Category", target: self, selector: #selector(showAddCategory))
        actionSheet.setStatusBarStyle(.lightContent)
        
        actionSheet.show()
    }
    
    @objc fileprivate func showAddTodo() {
        // Play click sound
        SoundManager.play(soundEffect: .Click)
    }

    /// Show add category view controller.
    
    @objc fileprivate func showAddCategory() {
        // Play click sound
        SoundManager.play(soundEffect: .Click)
        Haptic.impact(.medium).generate()
        
        performSegue(withIdentifier: Segue.ShowCategory.rawValue, sender: nil)
    }
    
    /// Additional preparation for storyboard segue.
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let id = segue.identifier else { return }
        
        switch id {
        case Segue.ShowCategory.rawValue:
            let destination = segue.destination as! UINavigationController
            let destinationViewController = destination.topViewController as! CategoryTableViewController
            // Pass through managed object context
            destinationViewController.managedObjectContext = managedObjectContext
            
            guard let categories = fetchedResultsController.fetchedObjects else { return }
            
            // Show edit category
            if let _ = sender, let index = currentRelatedCategoryIndex {
                destinationViewController.category = categories[index.item]
                destinationViewController.delegate = self
            } else {
                destinationViewController.newCategoryOrder = Int16(categories.count)
            }
        default:
            break
        }
    }
    
}

// MARK: - Animations.

extension ToDoOverviewViewController {
    
    /// Start animations
    
    fileprivate func startAnimations() {
        animateNavigationBar()
        animateUserViews()
    }
    
    /// Animate user related views.
    
    fileprivate func animateUserViews() {
        // Fade in and move from up animation to `user avatar`
        userAvatarContainerView.alpha = 0
        userAvatarContainerView.transform = .init(translationX: 0, y: -40)
        UIView.animate(withDuration: 0.55, delay: 0.7, options: [.curveEaseInOut], animations: {
            self.userAvatarContainerView.alpha = 1
            self.userAvatarContainerView.transform = .init(translationX: 0, y: 0)
        }, completion: nil)
        
        // Fade in and move from left animation to `greeting label`
        greetingLabel.alpha = 0
        greetingLabel.transform = .init(translationX: -80, y: 0)
        UIView.animate(withDuration: 0.55, delay: 0.85, options: [.curveEaseInOut], animations: {
            self.greetingLabel.alpha = 1
            self.greetingLabel.transform = .init(translationX: 0, y: 0)
        }, completion: nil)

        // Fade in animation to `time label` and `message label`
        greetingWithTimeLabel.alpha = 0
        todoMessageLabel.alpha = 0
        UIView.animate(withDuration: 0.62, delay: 1, options: [.curveEaseInOut], animations: {
            self.greetingWithTimeLabel.alpha = 1
            self.todoMessageLabel.alpha = 1
        }, completion: nil)
    }
    
    /// Animate todo collection view for categories.
    
    fileprivate func animateTodoCollectionView() {
        todosCollectionView.animateViews(animations: [AnimationType.from(direction: .bottom, offset: 40)], delay: 0.1, duration: 0.6)
    }
}

// MARK: - Collection View Delegate and Data Source.

extension ToDoOverviewViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    /// Number of sections.
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    /// Number of items in section.
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = fetchedResultsController.sections?[section] else { return 0 }
        
        // One more for adding category
        return section.numberOfObjects + 1
    }
    
    /// Configure each collection view cell.
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard !isAddCategoryCell(indexPath) else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddCategoryOverviewCollectionViewCell.identifier, for: indexPath) as? AddCategoryOverviewCollectionViewCell else { return UICollectionViewCell() }
            
            return cell
        }
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ToDoCategoryOverviewCollectionViewCell.identifier, for: indexPath) as? ToDoCategoryOverviewCollectionViewCell else { return UICollectionViewCell() }
        
        // Configure cell
        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    /// Configure category cell.
    
    fileprivate func configure(cell: ToDoCategoryOverviewCollectionViewCell, at indexPath: IndexPath) {
        let category = fetchedResultsController.object(at: indexPath)
        
        cell.category = category
        cell.delegate = self
    }
    
    /// Detect if the index path corresponds to add category cell.
    ///
    /// - Parameter indexPath: The index path
    /// - Returns: Is add category cell for the index path or not.
    
    fileprivate func isAddCategoryCell(_ indexPath: IndexPath) -> Bool {
        return indexPath.item == (todosCollectionView.numberOfItems(inSection: 0) - 1)
    }
    
    /// Select item for collection view.
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isAddCategoryCell(indexPath) {
            showAddCategory()
        } else {
            
        }
    }
    
    /// Enable re-order ability for category that has been long pressed.
    
    @objc func categoryLongPressed(recognizer: UILongPressGestureRecognizer!) {
        switch recognizer.state {
        case .began:
            guard let selectedIndexPath = todosCollectionView.indexPathForItem(at: recognizer.location(in: todosCollectionView)) else { break }
            
            todosCollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            todosCollectionView.updateInteractiveMovementTargetPosition(recognizer.location(in: recognizer.view!))
        case .ended:
            todosCollectionView.endInteractiveMovement()
        default:
            todosCollectionView.cancelInteractiveMovement()
        }
    }
    
    /// Is the cell movable or not.
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return !isAddCategoryCell(indexPath)
    }
    
    /// Move cell to a new location.
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard var categories = fetchedResultsController.fetchedObjects, sourceIndexPath != destinationIndexPath, !isAddCategoryCell(destinationIndexPath) else {
            // Scroll back if anything went wrong
            todosCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .centeredHorizontally, animated: true)
            
            return
        }
        // Re-arrange category from source to destination
        categories.insert(categories.remove(at: sourceIndexPath.item), at: destinationIndexPath.item)
        // Save to order attribute
        let _ = categories.map {
            let newOrder = Int16(categories.index(of: $0)!)
            
            if $0.order != newOrder {
                $0.order = newOrder
            }
        }
        // If the category is re-ordered, scroll to that category
        collectionView.scrollToItem(at: destinationIndexPath, at: .centeredHorizontally, animated: true)
    }
}

// MARK: - Handle Collection View Flow Layout.

extension ToDoOverviewViewController: UICollectionViewDelegateFlowLayout {

    /// Set the collection items size.
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width * 0.8, height: collectionView.bounds.height)
    }
    
    /// Set spacing for each collection item.

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        var insets = collectionView.contentInset
    
        let spacing = (view.frame.size.width - (collectionView.collectionViewLayout as! UICollectionViewFlowLayout).itemSize.width) / 2
        insets.left = spacing
        insets.right = spacing
        
        return insets
    }
    
}

// MARK: - Handle Fetched Results Controller Delegate Methods.

extension ToDoOverviewViewController: NSFetchedResultsControllerDelegate {
    
    /// When the content did change with delete, insert, move and update type.
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .delete:
            // Item has been deleted
            if anObject is Category, let indexPath = indexPath {
                // If a category has been deleted
                // Show banner message
                // FIXME: Localization
                NotificationManager.showBanner(title: "Category Deleted!", type: .success)
                // Perform deletion
                todosCollectionView.performBatchUpdates({
                    todosCollectionView.deleteItems(at: [indexPath])
                })
            }
        case .insert:
            // Item has been inserted
            if anObject is Category, let indexPath = newIndexPath {
                // If a new category has been inserted
                // Show banner message
                // FIXME: Localization
                NotificationManager.showBanner(title: "Created Category - \((anObject as! Category).name!)", type: .success)
                // Perform insertion to the last category
                todosCollectionView.performBatchUpdates({
                    todosCollectionView.insertItems(at: [indexPath])
                }, completion: {
                    if $0 {
                        // Once completed, scroll to current category
                        self.todosCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
                    }
                })
            }
        case .update:
            // Item has been updated
            if anObject is Category, let indexPath = indexPath {
                // If a category has been updated
                // Re-configure the cell
                todosCollectionView.performBatchUpdates({
                    todosCollectionView.reloadItems(at: [indexPath])
                })
            }
        default:
            break
        }
    }
    
    /// When the content did change.
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        todosCollectionView.reloadData()
    }
}

// MARK: - Handle Category Actions.

extension ToDoOverviewViewController: ToDoCategoryOverviewCollectionViewCellDelegate {
    
    /// Display category menu.
    
    func showCategoryMenu(cell: ToDoCategoryOverviewCollectionViewCell) {
        guard let selectedIndexPath = todosCollectionView.indexPath(for: cell) else { return }
        currentRelatedCategoryIndex = selectedIndexPath
        
        // Generate haptic feedback
        Haptic.impact(.light).generate()
        
        let category = fetchedResultsController.object(at: selectedIndexPath)
        
        // FIXME: Localization
        let actionSheet = Hokusai(headline: "Category - \(category.name!)")
        
        actionSheet.colors = HOKColors(backGroundColor: UIColor.flatBlack(), buttonColor: category.categoryColor(), cancelButtonColor: UIColor(hexString: "444444"), fontColor: UIColor(contrastingBlackOrWhiteColorOn: category.categoryColor(), isFlat: true))
        actionSheet.cancelButtonTitle = "Cancel"
        
        let _ = actionSheet.addButton("Edit Category", target: self, selector: #selector(showEditCategory))
        let _ = actionSheet.addButton("Delete Category", target: self, selector: #selector(showDeleteCategory))
        actionSheet.setStatusBarStyle(.lightContent)
        
        // Present actions sheet
        actionSheet.show()
    }
    
    /// Show category edit controller.
    
    @objc private func showEditCategory() {
        // Play click sound and haptic feedback
        SoundManager.play(soundEffect: .Click)
        Haptic.impact(.medium).generate()
        
        performSegue(withIdentifier: Segue.ShowCategory.rawValue, sender: true)
    }
    
    /// Show alert for deleting category.
    
    @objc private func showDeleteCategory() {
        guard let index = currentRelatedCategoryIndex else { return }
        
        // Generate warning haptic
        Haptic.notification(.warning).generate()
        
        let category = fetchedResultsController.object(at: index)
        
        // FIXME: Localization
        let alert = FCAlertView(type: .caution)
        // Configure alert
        alert.colorScheme = .flatRed()
        alert.delegate = self
        // Show alert for confirmation
        alert.showAlert(
            inView: self,
            withTitle: "Delete \(category.name ?? "Category")?",
            withSubtitle: "Once you've deleted the category, all of its to-do items will be removed too.",
            withCustomImage: nil,
            withDoneButtonTitle: "Delete",
            andButtons: ["Nope"]
        )
    }
    
}

// MARK: - Category Table View Controller Delegate Methods.

extension ToDoOverviewViewController: CategoryTableViewControllerDelegate {
    
    /// Delete the category.
    
    func deleteCategory(_ category: Category) {
        guard let context = managedObjectContext else { return }
        
        // Delete from context
        context.delete(category)
    }
    
}
// MARK: - Alert Controller Delegate Methods.

extension ToDoOverviewViewController: FCAlertViewDelegate {
    
    /// Dismissal of alert.
    
    func alertView(alertView: FCAlertView, clickedButtonIndex index: Int, buttonTitle title: String) {
        alertView.dismissAlertView()
    }
    
    /// Confirmation of alert.
    
    func FCAlertDoneButtonClicked(alertView: FCAlertView) {
        guard let index = currentRelatedCategoryIndex else { return }
        
        // Delete from results
        deleteCategory(fetchedResultsController.object(at: index))
    }
}
