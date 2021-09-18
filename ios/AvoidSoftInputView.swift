class AvoidSoftInputView: RCTView {
    let SOFT_INPUT_HEIGHT_KEY = "softInputHeight"
    
    var focusedInput: UIView? = nil
    var originY: CGFloat? = nil
    var isViewSlideUp: Bool = false
    var isViewSlidingDown: Bool = false
    var isViewSlidingUp: Bool = false
    var scrollContentInset: UIEdgeInsets = UIEdgeInsets.zero
    var scrollIndicatorInsets: UIEdgeInsets = UIEdgeInsets.zero
    var bottomOffset: CGFloat = 0
    var _avoidOffset: CGFloat = 0
    
    @objc var avoidOffset: NSNumber? = 0 {
        didSet {
            _avoidOffset = CGFloat(avoidOffset?.floatValue ?? 0)
        }
    }
    @objc var onSoftInputHidden: RCTBubblingEventBlock?
    @objc var onSoftInputShown: RCTBubblingEventBlock?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        #endif
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #endif
    }
    
    #if os(iOS)
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo, let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        let keyboardFrame = keyboardSize.cgRectValue

        if let onShow = onSoftInputShown {
            onShow([SOFT_INPUT_HEIGHT_KEY: keyboardFrame.height])
        }
        
        if self.isViewSlideUp || self.isViewSlidingUp {
            return
        }
        
        self.isViewSlidingUp = true
        
        guard let viewController = RCTPresentedViewController(), let focusedInput = findFirstResponder(view: viewController.view), let rootView = viewController.view else {
            self.isViewSlidingUp = false
            return
        }
        
        if originY == nil {
            originY = self.frame.origin.y
        }
        self.focusedInput = focusedInput

        guard let keyboardOffset = computeKeyboardOffset(keyboardHeight: keyboardFrame.height, firstResponder: focusedInput, containerView: self, rootView: rootView) else {
            self.isViewSlidingUp = false
            return
        }
                
        self.bottomOffset = keyboardOffset + _avoidOffset
        UIView.animate(withDuration: 0.66, delay: 0.3, options: [.beginFromCurrentState]) {
            if let scrollView = findScrollViewForFirstResponder(view: focusedInput, rootView: self) {
                let contentInsets = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: self.bottomOffset, right: 0.0)
                self.scrollContentInset = scrollView.contentInset
                self.scrollIndicatorInsets = scrollView.scrollIndicatorInsets
                scrollView.contentInset = contentInsets
                scrollView.scrollIndicatorInsets = contentInsets
            } else if let originY = self.originY {
                self.frame.origin.y = originY - self.bottomOffset
            }
        } completion: { isCompleted in
            self.isViewSlidingUp = false
            self.isViewSlideUp = true
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if let onHide = onSoftInputHidden {
            onHide([SOFT_INPUT_HEIGHT_KEY: 0])
        }
        
        if (!self.isViewSlideUp && !self.isViewSlidingUp) || self.isViewSlidingDown {
            return
        }
        
        self.isViewSlidingDown = true
        
        guard let focusedInput = focusedInput else {
            self.isViewSlidingDown = false
            return
        }
        
        UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState]) {
            if let scrollView = findScrollViewForFirstResponder(view: focusedInput, rootView: self) {
                scrollView.contentInset = self.scrollContentInset
                scrollView.scrollIndicatorInsets = self.scrollIndicatorInsets
                self.scrollContentInset = UIEdgeInsets.zero
                self.scrollIndicatorInsets = UIEdgeInsets.zero
            } else {
                self.frame.origin.y += self.bottomOffset
            }
        } completion: { isCompleted in
            self.originY = nil
            self.focusedInput = nil
            self.bottomOffset = 0
            self.isViewSlideUp = false
            self.isViewSlidingDown = false
        }
    }
    #endif
}