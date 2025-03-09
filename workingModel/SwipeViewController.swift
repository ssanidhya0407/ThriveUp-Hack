import UIKit
import Instructions
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class SwipeViewController: UIViewController, CoachMarksControllerDataSource, CoachMarksControllerDelegate {
    private var eventStack: [EventModel] = []
    private var userStack: [UserDetails] = []
    private var bookmarkedEvents: [EventModel] = []
    private var bookmarkedUsers: [UserDetails] = []
    private let db = Firestore.firestore()

    private let cardContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // CoachMarksController instance for the guided tour
    let coachMarksController = CoachMarksController()
    let swipeButton = UIButton(type: .system)
    let hackathonButton = UIButton(type: .system)
    let filterButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGray6

        setupTitleStackView()
        setupViews()
        setupConstraints()
        fetchEventsFromDatabase()
        fetchUsersFromDatabase()

        // Configure CoachMarksController
        coachMarksController.dataSource = self
        coachMarksController.delegate = self

        // Check if it's the user's first time logging in
        if isFirstTimeUser() {
            askForTutorial()
        }

        // Observe for notification to show the instructions
        NotificationCenter.default.addObserver(self, selector: #selector(showInstructions), name: NSNotification.Name("ShowInstructions"), object: nil)
    }

    @objc private func showInstructions() {
        askForTutorial()
    }

    private func setupTitleStackView() {
        // Configure swipeButton
        swipeButton.setTitle("Flick", for: .normal)
        swipeButton.setTitleColor(.orange, for: .normal)
        swipeButton.titleLabel?.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        swipeButton.addTarget(self, action: #selector(handleSwipeButtonTapped), for: .touchUpInside)

        // Configure hackathonButton
        hackathonButton.setTitle("HackMate", for: .normal)
        hackathonButton.setTitleColor(.gray, for: .normal)
        hackathonButton.titleLabel?.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        hackathonButton.addTarget(self, action: #selector(handleHackathonButtonTapped), for: .touchUpInside)

        // Configure filterButton
        filterButton.setImage(UIImage(systemName: "line.horizontal.3.decrease.circle"), for: .normal)
        filterButton.tintColor = .black
        filterButton.addTarget(self, action: #selector(handleFilterButtonTapped), for: .touchUpInside)

        // Configure titleStackView
        let titleStackView = UIStackView(arrangedSubviews: [swipeButton, hackathonButton, filterButton])
        titleStackView.axis = .horizontal
        titleStackView.alignment = .center
        titleStackView.distribution = .equalSpacing
        titleStackView.spacing = 8

        // Add titleStackView to the view
        view.addSubview(titleStackView)
        titleStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleStackView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    @objc private func handleSwipeButtonTapped() {
        swipeButton.setTitleColor(.orange, for: .normal)
        hackathonButton.setTitleColor(.gray, for: .normal)
        displayTopCards(for: .swipe)
    }

    @objc private func handleHackathonButtonTapped() {
        swipeButton.setTitleColor(.gray, for: .normal)
        hackathonButton.setTitleColor(.orange, for: .normal)
        displayTopCards(for: .hackathon)
    }

    @objc private func handleFilterButtonTapped() {
        guard let userId = Auth.auth().currentUser?.uid else {
            promptUserToSignIn()
            return
        }

        let interestViewController = InterestsViewController()
        interestViewController.userID = userId
        navigationController?.pushViewController(interestViewController, animated: true)
    }

    private func promptUserToSignIn() {
        let alert = UIAlertController(title: "Sign In Required", message: "Please sign in to access your interests", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sign In", style: .default, handler: { _ in
            // Navigate to sign-in view controller
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func setupViews() {
        view.addSubview(cardContainerView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            cardContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            cardContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            cardContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            cardContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }

    private func fetchEventsFromDatabase() {
        db.collection("events").getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error fetching events: \(error.localizedDescription)")
                return
            }

            var fetchedEvents: [EventModel] = []

            snapshot?.documents.forEach { document in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: document.data())
                    let event = try JSONDecoder().decode(EventModel.self, from: jsonData)
                    fetchedEvents.append(event)
                } catch {
                    print("Error decoding event: \(error.localizedDescription)")
                }
            }

            self?.eventStack = fetchedEvents.reversed()

            DispatchQueue.main.async {
                self?.displayTopCards(for: .swipe)
            }
        }
    }


    private func fetchUsersFromDatabase() {
        db.collection("users").getDocuments { [weak self] (snapshot, error) in
            if let error = error {
                print("Error fetching users: \(error.localizedDescription)")
                return
            }

            var fetchedUsers: [UserDetails] = []

            snapshot?.documents.forEach { document in
                let data = document.data()
                let id = document.documentID
                let name = data["name"] as? String ?? ""
                let description = data["Description"] as? String ?? "No Description Available"
                let imageUrl = data["profileImageURL"] as? String ?? ""
                let githubUrl = data["githubUrl"] as? String ?? "Not Available"
                let linkedinUrl = data["linkedinUrl"] as? String ?? "Not Available"
                let techStack = data["techStack"] as? String ?? "Unknown"
                let contact = data["ContactDetails"] as? String ?? "Not Available"

                let user = UserDetails(
                    id: id,
                    name: name,
                    description: description,
                    imageUrl: imageUrl,
                    contact: contact, githubUrl: githubUrl,
                    linkedinUrl: linkedinUrl,
                    techStack: techStack
                )
                
                fetchedUsers.append(user)
            }

            self?.userStack = fetchedUsers.reversed()
            self?.displayTopUserCards()
        }
    }



    private func displayTopCards(for category: Category) {
        cardContainerView.subviews.forEach { $0.removeFromSuperview() }

        let cards: [UIView]
        switch category {
        case .swipe:
            cards = eventStack.suffix(3).map { createCard(for: $0) }
        case .hackathon:
            cards = userStack.suffix(3).map { createCard(for: $0) }
        }

        for cardView in cards {
            cardContainerView.addSubview(cardView)
            cardView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                cardView.leadingAnchor.constraint(equalTo: cardContainerView.leadingAnchor),
                cardView.trailingAnchor.constraint(equalTo: cardContainerView.trailingAnchor),
                cardView.topAnchor.constraint(equalTo: cardContainerView.topAnchor),
                cardView.bottomAnchor.constraint(equalTo: cardContainerView.bottomAnchor)
            ])

            cardContainerView.sendSubviewToBack(cardView)
        }
    }

    private func createCard(for event: EventModel) -> UIView {
        let cardView = FlippableCardView(event: event)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        cardView.addGestureRecognizer(panGesture)

        let bookmarkButton = createButton(imageName: "bookmark.fill", tintColor: .systemOrange)
        let discardButton = createButton(imageName: "xmark", tintColor: .systemRed)

        bookmarkButton.alpha = 0 // Initially hide the bookmark button
        discardButton.alpha = 0 // Initially hide the discard button

        cardView.addSubview(bookmarkButton)
        cardView.addSubview(discardButton)

        NSLayoutConstraint.activate([
            bookmarkButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            bookmarkButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 60),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 60),

            discardButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            discardButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            discardButton.widthAnchor.constraint(equalToConstant: 60),
            discardButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        cardView.bookmarkButton = bookmarkButton
        cardView.discardButton = discardButton

        return cardView
    }

    private func createCard(for user: UserDetails) -> UIView {
        let cardView = UserProfileCardView(user: user)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleUserSwipe(_:)))
        cardView.addGestureRecognizer(panGesture)

        let bookmarkButton = createButton(imageName: "bookmark.fill", tintColor: .systemOrange)
        let discardButton = createButton(imageName: "xmark", tintColor: .systemRed)

        bookmarkButton.alpha = 0 // Initially hide the bookmark button
        discardButton.alpha = 0 // Initially hide the discard button

        cardView.bookmarkButton = bookmarkButton
        cardView.discardButton = discardButton

        cardView.addSubview(bookmarkButton)
        cardView.addSubview(discardButton)

        NSLayoutConstraint.activate([
            bookmarkButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            bookmarkButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 60),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 60),

            discardButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            discardButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            discardButton.widthAnchor.constraint(equalToConstant: 60),
            discardButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        return cardView
    }

    private func createButton(imageName: String, tintColor: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.tintColor = tintColor
        button.backgroundColor = UIColor(white: 1, alpha: 0.75)
        button.layer.cornerRadius = 30
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    @objc private func handleSwipe(_ gesture: UIPanGestureRecognizer) {
        guard let cardView = gesture.view as? FlippableCardView else { return }
        let translation = gesture.translation(in: view)
        let xFromCenter = translation.x

        switch gesture.state {
        case .began:
            // Hide both buttons initially
            cardView.bookmarkButton?.alpha = 0
            cardView.discardButton?.alpha = 0
        case .changed:
            cardView.transform = CGAffineTransform(translationX: xFromCenter, y: 0)
                .rotated(by: xFromCenter / 200)
            cardView.alpha = 1 - abs(xFromCenter) / view.frame.width

            // Show the appropriate button based on swipe direction
            if xFromCenter > 0 {
                cardView.bookmarkButton?.alpha = 1
                cardView.discardButton?.alpha = 0
            } else {
                cardView.bookmarkButton?.alpha = 0
                cardView.discardButton?.alpha = 1
            }

        case .ended:
            if xFromCenter > 100 {
                bookmarkEvent(for: cardView.event)
                animateCardOffScreen(cardView, toRight: true)
            } else if xFromCenter < -100 {
                discardEvent(for: cardView.event)
                animateCardOffScreen(cardView, toRight: false)
            } else {
                UIView.animate(withDuration: 0.3) {
                    cardView.transform = CGAffineTransform.identity
                    cardView.alpha = 1
                    cardView.bookmarkButton?.alpha = 0
                    cardView.discardButton?.alpha = 0
                }
            }
        default:
            UIView.animate(withDuration: 0.3) {
                cardView.transform = CGAffineTransform.identity
                cardView.alpha = 1
                cardView.bookmarkButton?.alpha = 0
                cardView.discardButton?.alpha = 0
            }
        }
    }

    @objc private func handleUserSwipe(_ gesture: UIPanGestureRecognizer) {
        guard let cardView = gesture.view as? UserProfileCardView else { return }
        let translation = gesture.translation(in: view)
        let xFromCenter = translation.x

        switch gesture.state {
        case .began:
            // Hide both buttons initially
            cardView.bookmarkButton?.alpha = 0
            cardView.discardButton?.alpha = 0
        case .changed:
            cardView.transform = CGAffineTransform(translationX: xFromCenter, y: 0)
                .rotated(by: xFromCenter / 200)
            cardView.alpha = 1 - abs(xFromCenter) / view.frame.width

            // Show the appropriate button based on swipe direction
            if xFromCenter > 0 {
                cardView.bookmarkButton?.alpha = 1
                cardView.discardButton?.alpha = 0
            } else {
                cardView.bookmarkButton?.alpha = 0
                cardView.discardButton?.alpha = 1
            }

        case .ended:
            if xFromCenter > 100 {
                bookmarkUser(for: cardView.user)
                animateUserCardOffScreen(cardView, toRight: true)
            } else if xFromCenter < -100 {
                discardUser(for: cardView.user)
                animateUserCardOffScreen(cardView, toRight: false)
            } else {
                UIView.animate(withDuration: 0.3) {
                    cardView.transform = CGAffineTransform.identity
                    cardView.alpha = 1
                    cardView.bookmarkButton?.alpha = 0
                    cardView.discardButton?.alpha = 0
                }
            }
        default:
            UIView.animate(withDuration: 0.3) {
                cardView.transform = CGAffineTransform.identity
                cardView.alpha = 1
                cardView.bookmarkButton?.alpha = 0
                cardView.discardButton?.alpha = 0
            }
        }
    }

    private func bookmarkUser(for user: UserDetails) {
        bookmarkedUsers.append(user)
        // Optionally: Save the bookmarked user to a database or UserDefaults
    }

    private func discardUser(for user: UserDetails) {
        userStack.removeAll { $0.name == user.name }
        displayTopUserCards()
    }

    private func animateCardOffScreen(_ cardView: FlippableCardView, toRight: Bool) {
        UIView.animate(withDuration: 0.5, animations: {
            cardView.transform = CGAffineTransform(translationX: toRight ? self.view.frame.width : -self.view.frame.width, y: 0)
            cardView.alpha = 0
        }) { _ in
            cardView.removeFromSuperview()
            if let index = self.eventStack.firstIndex(of: cardView.event) {
                self.eventStack.remove(at: index)
            }
            self.displayTopCards(for: .swipe)
        }
    }

    private func animateUserCardOffScreen(_ cardView: UserProfileCardView, toRight: Bool) {
        UIView.animate(withDuration: 0.5, animations: {
            cardView.transform = CGAffineTransform(translationX: toRight ? self.view.frame.width : -self.view.frame.width, y: 0)
            cardView.alpha = 0
        }) { _ in
            cardView.removeFromSuperview()
            if let index = self.userStack.firstIndex(where: { $0.name == cardView.user.name }) {
                self.userStack.remove(at: index)
            }
            self.displayTopUserCards()
        }
    }

    private func bookmarkEvent(for event: EventModel) {
        bookmarkedEvents.append(event)
    }

    private func discardEvent(for event: EventModel) {
        eventStack.removeAll { $0.eventId == event.eventId }
        displayTopCards(for: .swipe)
    }

    private func isFirstTimeUser() -> Bool {
        // Implement logic to check if it's the first time user
        return false
    }

    private func displayTopUserCards() {
        cardContainerView.subviews.forEach { $0.removeFromSuperview() }

        guard !userStack.isEmpty else { return }

        let topUsers = userStack.suffix(3)
        for user in topUsers {
            let userCardView = UserProfileCardView(user: user)
            userCardView.translatesAutoresizingMaskIntoConstraints = false
            cardContainerView.addSubview(userCardView)

            NSLayoutConstraint.activate([
                userCardView.topAnchor.constraint(equalTo: cardContainerView.topAnchor),
                userCardView.bottomAnchor.constraint(equalTo: cardContainerView.bottomAnchor),
                userCardView.leadingAnchor.constraint(equalTo: cardContainerView.leadingAnchor),
                userCardView.trailingAnchor.constraint(equalTo: cardContainerView.trailingAnchor)
            ])

            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleUserSwipe(_:)))
            userCardView.addGestureRecognizer(panGesture)

            cardContainerView.sendSubviewToBack(userCardView)
        }
    }

    private func askForTutorial() {
        let alert = UIAlertController(title: "Welcome!", message: "Would you like to take a quick tour of the app?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
            self.startGuidedTour()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func startGuidedTour() {
        coachMarksController.start(in: .window(over: self))
    }

    // MARK: - CoachMarksControllerDataSource

    func numberOfCoachMarks(for coachMarksController: CoachMarksController) -> Int {
        return 3
    }

    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarkAt index: Int) -> CoachMark {
        switch index {
        case 0:
            return coachMarksController.helper.makeCoachMark(for: swipeButton)
        case 1:
            return coachMarksController.helper.makeCoachMark(for: hackathonButton)
        case 2:
            return coachMarksController.helper.makeCoachMark(for: filterButton)
        default:
            return coachMarksController.helper.makeCoachMark()
        }
    }

    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarkViewsAt index: Int, madeFrom coachMark: CoachMark) -> (bodyView: UIView & CoachMarkBodyView, arrowView: (UIView & CoachMarkArrowView)?) {
        let hintText: String
        switch index {
        case 0:
            hintText = "Tap here to swipe through events."
        case 1:
            hintText = "Tap here to view hackathon matches."
        case 2:
            hintText = "Tap here to filter your interests."
        default:
            hintText = ""
        }

        let coachViews = coachMarksController.helper.makeDefaultCoachViews(withArrow: true, arrowOrientation: coachMark.arrowOrientation)
        coachViews.bodyView.hintLabel.text = hintText
        coachViews.bodyView.nextLabel.text = "Next"

        return (bodyView: coachViews.bodyView, arrowView: coachViews.arrowView)
    }
}
        
enum Category {
    case swipe
    case hackathon
}


class UserProfileCardView: UIView {
    var user: UserDetails
    var bookmarkButton: UIButton?
    var discardButton: UIButton?
    var profileImageView: UIImageView!
    var nameLabel: UILabel!
    var aboutTitleLabel: UILabel!
    var aboutLabel: UILabel!
    var githubTabView: UIView!
    var linkedInTabView: UIView!
    var socialProfilesTitleLabel: UILabel!
    var techStackTitleLabel: UILabel!
    var techStackView: UIView!
    var techStackGridView: UIStackView!

    init(user: UserDetails) {
        self.user = user
        super.init(frame: .zero)
        setupViews()
        fetchUserDetails()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .white
        layer.cornerRadius = 20
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowRadius = 10
        layer.masksToBounds = false

        profileImageView = UIImageView()
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 40
        profileImageView.layer.borderWidth = 2
        profileImageView.layer.borderColor = UIColor.white.cgColor
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.isUserInteractionEnabled = true

        if let url = URL(string: user.imageUrl) {
            profileImageView.loadImage(from: url)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(enlargeProfileImage))
        profileImageView.addGestureRecognizer(tapGesture)

        nameLabel = UILabel()
        nameLabel.text = user.name
        nameLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutTitleLabel = UILabel()
        aboutTitleLabel.text = "About"
        aboutTitleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        aboutTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        aboutLabel = UILabel()
        aboutLabel.font = UIFont.systemFont(ofSize: 16)
        aboutLabel.numberOfLines = 0
        aboutLabel.translatesAutoresizingMaskIntoConstraints = false

        socialProfilesTitleLabel = UILabel()
        socialProfilesTitleLabel.text = "Social Profiles"
        socialProfilesTitleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        socialProfilesTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        githubTabView = createTabView(iconName: "logo.github", title: "GitHub", url: user.githubUrl ?? "")
        linkedInTabView = createTabView(iconName: "logo.linkedin", title: "LinkedIn", url: user.linkedinUrl ?? "")

        techStackTitleLabel = UILabel()
        techStackTitleLabel.text = "Tech Stack"
        techStackTitleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        techStackTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        techStackView = UIView()
        techStackView.translatesAutoresizingMaskIntoConstraints = false

        techStackGridView = UIStackView()
        techStackGridView.axis = .vertical
        techStackGridView.spacing = 16
        techStackGridView.distribution = .fillEqually
        techStackGridView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(profileImageView)
        addSubview(nameLabel)
        addSubview(aboutTitleLabel)
        addSubview(aboutLabel)
        addSubview(socialProfilesTitleLabel)
        addSubview(githubTabView)
        addSubview(linkedInTabView)
        addSubview(techStackTitleLabel)
        addSubview(techStackView)
        techStackView.addSubview(techStackGridView)

        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            profileImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            profileImageView.widthAnchor.constraint(equalToConstant: 80),
            profileImageView.heightAnchor.constraint(equalToConstant: 80),

            nameLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            aboutTitleLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 16),
            aboutTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            aboutTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            aboutLabel.topAnchor.constraint(equalTo: aboutTitleLabel.bottomAnchor, constant: 8),
            aboutLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            aboutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            socialProfilesTitleLabel.topAnchor.constraint(equalTo: aboutLabel.bottomAnchor, constant: 16),
            socialProfilesTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            socialProfilesTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            githubTabView.topAnchor.constraint(equalTo: socialProfilesTitleLabel.bottomAnchor, constant: 8),
            githubTabView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            githubTabView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            githubTabView.heightAnchor.constraint(equalToConstant: 44),

            linkedInTabView.topAnchor.constraint(equalTo: githubTabView.bottomAnchor, constant: 8),
            linkedInTabView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            linkedInTabView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            linkedInTabView.heightAnchor.constraint(equalToConstant: 44),

            techStackTitleLabel.topAnchor.constraint(equalTo: linkedInTabView.bottomAnchor, constant: 32),
            techStackTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            techStackTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            techStackView.topAnchor.constraint(equalTo: techStackTitleLabel.bottomAnchor, constant: 4),
            techStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            techStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            techStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            techStackGridView.topAnchor.constraint(equalTo: techStackView.topAnchor),
            techStackGridView.leadingAnchor.constraint(equalTo: techStackView.leadingAnchor),
            techStackGridView.trailingAnchor.constraint(equalTo: techStackView.trailingAnchor),
            techStackGridView.bottomAnchor.constraint(equalTo: techStackView.bottomAnchor)
        ])

        setupTechStack()
    }

    private func setupTechStack() {
        techStackGridView.arrangedSubviews.forEach { $0.removeFromSuperview() } // Clear existing views

        let techStackItems = user.techStack.components(separatedBy: ", ")
        let columns = 2
        var currentRowStack: UIStackView?

        for (index, item) in techStackItems.enumerated() {
            if index % columns == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.spacing = 12
                currentRowStack?.distribution = .fillEqually
                techStackGridView.addArrangedSubview(currentRowStack!)
            }

            let button = UIButton(type: .system)
            button.setTitle(item, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            button.backgroundColor = UIColor.systemGray5
            button.layer.cornerRadius = 8
            button.clipsToBounds = true

            currentRowStack?.addArrangedSubview(button)
        }
    }

    @objc private func enlargeProfileImage() {
        guard let imageView = profileImageView else { return }
        
        // Create a new view controller to present the enlarged image
        let enlargedImageViewController = UIViewController()
        enlargedImageViewController.view.backgroundColor = .black
        
        // Create an image view to display the enlarged image
        let enlargedImageView = UIImageView(image: imageView.image)
        enlargedImageView.contentMode = .scaleAspectFit
        enlargedImageView.frame = enlargedImageViewController.view.frame
        enlargedImageViewController.view.addSubview(enlargedImageView)
        
        // Add a tap gesture to dismiss the enlarged image view
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissEnlargedImage))
        enlargedImageViewController.view.addGestureRecognizer(tapGesture)
        
        // Present the view controller
        if let topViewController = UIApplication.shared.keyWindow?.rootViewController {
            topViewController.present(enlargedImageViewController, animated: true, completion: nil)
        }
    }

    @objc private func dismissEnlargedImage(_ sender: UITapGestureRecognizer) {
        sender.view?.window?.rootViewController?.dismiss(animated: true, completion: nil)
    }

    private func createTabView(iconName: String, title: String, url: String) -> UIView {
        let tabView = UIView()
        tabView.backgroundColor = .white
        tabView.layer.cornerRadius = 8
        tabView.layer.borderWidth = 1
        tabView.layer.borderColor = UIColor.lightGray.cgColor
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let iconImageView = UIImageView()
        iconImageView.tintColor = .black
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        if let profileName = url.split(separator: "/").last {
            titleLabel.text = "\(title) Profile /\(profileName)"
        } else {
            titleLabel.text = title
        }

        tabView.addSubview(iconImageView)
        tabView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: tabView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: tabView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: tabView.centerYAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openURL(_:)))
        tabView.addGestureRecognizer(tapGesture)
        tabView.accessibilityLabel = url

        // Fetch and set the icon image
        fetchIconImage(named: iconName) { image in
            iconImageView.image = image
        }

        return tabView
    }

    private func fetchIconImage(named iconName: String, completion: @escaping (UIImage?) -> Void) {
        let storageRef = Storage.storage().reference().child("logo_images/\(iconName).png")
        storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error fetching image: \(error.localizedDescription)")
                completion(nil)
                return
            }
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    @objc private func openURL(_ sender: UITapGestureRecognizer) {
        if let urlString = sender.view?.accessibilityLabel, var urlWithScheme = URL(string: urlString) {
            if !urlString.hasPrefix("http") {
                urlWithScheme = URL(string: "https://\(urlString)")!
            }
            UIApplication.shared.open(urlWithScheme)
        }
    }

    private func fetchUserDetails() {
        print("Fetching user details for user: \(user.id)")
        let db = Firestore.firestore()
        db.collection("users").document(user.id).getDocument { [weak self] document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                print("No user data found for user \(self?.user.id ?? "")")
                return
            }

            if let githubUrl = data["githubUrl"] as? String, !githubUrl.isEmpty {
                print("Fetched GitHub URL: \(githubUrl)")
                self?.user.githubUrl = githubUrl
                self?.githubTabView.accessibilityLabel = githubUrl
                if let githubLabel = self?.githubTabView.subviews.compactMap({ $0 as? UILabel }).first,
                   let profileName = githubUrl.split(separator: "/").last {
                    githubLabel.text = "GitHub Account"
                }
            } else {
                if let githubLabel = self?.githubTabView.subviews.compactMap({ $0 as? UILabel }).first {
                    githubLabel.text = "Not Available"
                }
            }

            if let linkedInUrl = data["linkedinUrl"] as? String, !linkedInUrl.isEmpty {
                print("Fetched LinkedIn URL: \(linkedInUrl)")
                self?.user.linkedinUrl = linkedInUrl
                self?.linkedInTabView.accessibilityLabel = linkedInUrl
                if let linkedInLabel = self?.linkedInTabView.subviews.compactMap({ $0 as? UILabel }).first,
                   let profileName = linkedInUrl.split(separator: "/").last {
                    linkedInLabel.text = "LinkedIn Profile"
                }
            } else {
                if let linkedInLabel = self?.linkedInTabView.subviews.compactMap({ $0 as? UILabel }).first {
                    linkedInLabel.text = "Not Available"
                }
            }

            if let about = data["Description"] as? String {
                print("Fetched description: \(about)")
                self?.aboutLabel.text = about
            }
        }
    }
}

extension UIImageView {
    func loadImage(from url: URL) {
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url) {
                DispatchQueue.main.async {
                    self.image = UIImage(data: data)
                }
            }
        }
    }
}



class FlippableCardView: UIView, UITableViewDataSource, UITableViewDelegate {
    private var isFlipped = false
    private let frontView = UIView()
    private let backView = UIView()
    private let gradientLayer = CAGradientLayer()
    let event: EventModel

    var bookmarkButton: UIButton?
    var discardButton: UIButton?

    private let detailItems: [(String, String)]

    init(event: EventModel) {
        self.event = event
        self.detailItems = [
            ("calendar", event.date),
            ("clock", event.time),
            ("location", event.location),
            ("person.2", "Organizer: \(event.organizerName)"),
            ("text.bubble", event.description ?? "No description available.")
        ]
        
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = backView.bounds
    }

    private func setupViews() {
        setupFrontView()
        setupBackView()

        addSubview(frontView)
        addSubview(backView)

        frontView.translatesAutoresizingMaskIntoConstraints = false
        backView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            frontView.topAnchor.constraint(equalTo: topAnchor),
            frontView.leadingAnchor.constraint(equalTo: leadingAnchor),
            frontView.trailingAnchor.constraint(equalTo: trailingAnchor),
            frontView.bottomAnchor.constraint(equalTo: bottomAnchor),

            backView.topAnchor.constraint(equalTo: topAnchor),
            backView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        backView.isHidden = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(flipCard))
        addGestureRecognizer(tapGesture)
    }

    private func setupFrontView() {
        frontView.backgroundColor = .white
        frontView.layer.cornerRadius = 20
        frontView.layer.shadowColor = UIColor.black.cgColor
        frontView.layer.shadowOpacity = 0.3
        frontView.layer.shadowOffset = CGSize(width: 0, height: 5)
        frontView.layer.shadowRadius = 10
        frontView.layer.masksToBounds = false

        let imageView = UIImageView(image: UIImage(named: event.imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        imageView.translatesAutoresizingMaskIntoConstraints = false
        frontView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: frontView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: frontView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: frontView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: frontView.bottomAnchor)
        ])
    }

    private func setupBackView() {
        backView.backgroundColor = .clear
        backView.layer.cornerRadius = 20
        backView.layer.masksToBounds = true

        gradientLayer.colors = [UIColor.systemOrange.cgColor, UIColor.systemRed.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 20
        backView.layer.insertSublayer(gradientLayer, at: 0)

        let titleLabel = UILabel()
        titleLabel.text = event.title
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.layer.cornerRadius = 20
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isScrollEnabled = false
        tableView.separatorStyle = .singleLine
        tableView.delegate = self
        tableView.dataSource = self
                tableView.register(DetailCell.self, forCellReuseIdentifier: "DetailCell")

                backView.addSubview(titleLabel)
                backView.addSubview(tableView)

                NSLayoutConstraint.activate([
                    titleLabel.topAnchor.constraint(equalTo: backView.topAnchor, constant: 32),
                    titleLabel.leadingAnchor.constraint(equalTo: backView.leadingAnchor, constant: 16),
                    titleLabel.trailingAnchor.constraint(equalTo: backView.trailingAnchor, constant: -16),

                    tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
                    tableView.leadingAnchor.constraint(equalTo: backView.leadingAnchor, constant: 16),
                    tableView.trailingAnchor.constraint(equalTo: backView.trailingAnchor, constant: -16),
                    tableView.bottomAnchor.constraint(equalTo: backView.bottomAnchor, constant: -16)
                ])
            }

            @objc private func flipCard() {
                let fromView = isFlipped ? backView : frontView
                let toView = isFlipped ? frontView : backView

                UIView.transition(from: fromView, to: toView, duration: 0.6, options: [.transitionFlipFromLeft, .showHideTransitionViews]) { [weak self] _ in
                    self?.isFlipped.toggle()
                }
            }

            func numberOfSections(in tableView: UITableView) -> Int {
                return detailItems.count
            }

            func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
                return 1
            }

            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "DetailCell", for: indexPath) as? DetailCell else {
                    return UITableViewCell()
                }

                let item = detailItems[indexPath.section]
                cell.configure(iconName: item.0, detail: item.1)

                return cell
            }

            func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
                switch section {
                case 0:
                    return "Date"
                case 1:
                    return "Time"
                case 2:
                    return "Location"
                case 3:
                    return "Organizer"
                case 4:
                    return "Description"
                default:
                    return nil
                }
            }
        }

        class DetailCell: UITableViewCell {
            private let iconImageView = UIImageView()
            private let detailLabel = UILabel()

            override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                super.init(style: style, reuseIdentifier: reuseIdentifier)
                setupViews()
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            private func setupViews() {
                backgroundColor = .clear

                iconImageView.tintColor = .white
                iconImageView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(iconImageView)

                detailLabel.font = UIFont.preferredFont(forTextStyle: .body)
                detailLabel.textColor = .label
                detailLabel.numberOfLines = 0
                detailLabel.translatesAutoresizingMaskIntoConstraints = false
                addSubview(detailLabel)

                NSLayoutConstraint.activate([
                    iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                    iconImageView.widthAnchor.constraint(equalToConstant: 24),
                    iconImageView.heightAnchor.constraint(equalToConstant: 24),

                    detailLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
                    detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    detailLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                    detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
                ])
            }

            func configure(iconName: String, detail: String) {
                iconImageView.image = UIImage(systemName: iconName)
                detailLabel.text = detail
            }
        }
