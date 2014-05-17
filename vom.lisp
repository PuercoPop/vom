(defpackage :vom
  (:use)
  (:import-from #:cl
                #:t #:nil
                #:defpackage #:*package* #:package-name #:find-package
                #:eval-when
                #:eval
                #:defun #:defmacro
                #:defvar #:defparameter
                #:declare
                #:assert
                #:member
                #:macro-function
                #:documentation
                #:let #:let* #:progn
                #:&rest #:&key
                #:if #:when #:unless
                #:loop
                #:car #:cdr #:cddr
                #:format
                #:identity
                #:get-universal-time
                #:string #:string-downcase #:make-string #:concatenate
                #:intern
                #:setf #:getf
                #:max #:min
                #:+ #:- #:> #:< #:<= #:>=
                #:apply #:funcall
                #:append #:list #:length)
  (:export #:config
           #:*log-stream*
           
           #:emerg
           #:alert
           #:crit
           #:error
           #:warn
           #:notice
           #:info
           #:debug
           #:debug1
           #:debug2))
(in-package :vom)

(eval-when (:load-toplevel :compile-toplevel)
  (defparameter *levels* '(:off 0)
    "Holds the log level mappings (keyword -> value).")
  
  (defparameter *max-level-name-length* 0
    "Holds the number of characters in the longest log-level name."))

(defvar *config* '(t :warn)
  "Holds the logging config as a plist. Holds package -> level mappings, using
   T as the default (used if logging from a package that hasn't been
   configured).")

(defvar *log-stream* t
  "Holds the stream we're logging to.")

(defun config (package-keyword level-name)
  "Configure the log level for a package. The log level is given as a keyword."
  (assert (member level-name *levels*))
  (let ((package-name (string (package-name (find-package package-keyword)))))
    (setf (getf *config* (intern package-name :keyword)) level-name)))

(defun timestamp ()
  "Get unix timestamp."
  (let ((diff 2208988800))  ; (encode-universal-time 0 0 0 1 1 1970 0)
    (- (get-universal-time) diff)))

(defun do-log (level-name log-level package-keyword format-str args)
  "The given data to the current *log-stream* stream."
  (declare (optimize (speed 3) (safety 0)
                     (debug 0) (space 0))
           (type keyword level-name package-keyword)
           (type integer log-level)
           (type string format-str)
           (type list args))
  (let* ((package (find-package package-keyword))
         (package-name (when package
                         (intern (package-name package) :keyword)))
         (package-level (getf *config* package-name))
         (package-level (if package-level
                            package-level
                            (getf *config* t)))
         (package-level-value (getf *levels* package-level 0)))
    (when (<= log-level package-level-value)
      (let* ((level-str (string level-name))
             (timestamp (timestamp))
             (format-str (concatenate 'string "~a<~a> [~a] ~a - " format-str "~%")))
        (apply 'format
               (append (list
                         *log-stream*
                         format-str)
                       (list 
                         (make-string (- *max-level-name-length* (length level-str))
                                      :initial-element #\space)
                         level-str
                         timestamp
                         (string-downcase (string package-keyword)))
                       args))))))

(defmacro define-level (name level-value)
  "Define a log level."
  (let ((macro-name (intern (format nil "LOG-~a" (string name))))
        (log-sym (intern (string name))))
    `(progn
       (setf (getf *levels* ,name) ,level-value)
       (defmacro ,macro-name (format-str &rest args)
         ,(format nil "Log output to the ~s log level (~a)" name (getf *levels* name))
         (let ((pkg (intern (package-name *package*) :keyword)))
           `(do-log ,,name ,,level-value ,pkg ,format-str ,args)))
       (setf (documentation ',log-sym 'function) (documentation ',macro-name 'function))
       (setf (macro-function ',log-sym) (macro-function ',macro-name))
       (setf *max-level-name-length* (max *max-level-name-length*
                                          (length (string ,name)))))))

(define-level :emerg 1)
(define-level :alert 2)
(define-level :crit 3)
(define-level :error 4)
(define-level :warn 5)
(define-level :notice 6)
(define-level :info 7)
(define-level :debug 8)
(define-level :debug1 9)
(define-level :debug2 10)
(define-level :debug3 11)
(define-level :debug4 12)

