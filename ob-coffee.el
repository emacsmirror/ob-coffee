;;; ob-coffee.el --- org-babel functions for coffee-script evaluation

;; Copyright (C) 2015 ZHOU Feng

;; Author: ZHOU Feng <zf.pascal@gmail.com>
;; URL: http://github.com/zweifisch/ob-coffee
;; Keywords: org babel coffee-script
;; Version: 0.0.1
;; Created: 30th Sep 2015
;; Package-Requires: ((org "8"))

;;; Commentary:
;;
;; org-babel functions for coffee-script evaluation
;;

;;; Code:
(require 'ob)

(defvar ob-coffee-process-output nil)

(defconst org-babel-header-args:coffee
  '((promise . :any))
  "ob-coffee header arguments")

(defconst ob-coffee-path-to-repl-js
  (concat
   (file-name-directory (or load-file-name buffer-file-name))
   "repl.js"))

(defun org-babel-execute:coffee (body params)
  (let ((session (cdr (assoc :session params)))
        (result-type (cdr (assoc :result-type params)))
        (tmp (org-babel-temp-file "coffee-")))
    (if (string= "none" session)
        (progn
          (with-temp-file tmp (insert (if (string= "output" result-type) body (ob-coffee-wrap body))))
          (replace-regexp-in-string
           "\x2029" ""
           (shell-command-to-string (format "coffee %s" tmp))))
      (ob-coffee-ensure-session session)
      (with-temp-file tmp (insert (ob-coffee-wrap body)))
      (shell-command-to-string (format "coffee --no-header -cb %s" tmp))
      (ob-coffee-eval session (format "eval(require('fs').readFileSync('%s.js', {encoding:'utf8'}))" tmp)))))

(defun ob-coffee-find-last-expression ()
  (beginning-of-line)
  (if (or (eolp) (looking-at-p "[ \t]"))
    (if (> (point) (point-min))
        (progn
          (forward-line -1)
          (ob-coffee-find-last-expression))
      nil)
    t))

(defun ob-coffee-wrap (body)
  (with-temp-buffer
    (insert body)
    (when (ob-coffee-find-last-expression)
      (insert "__ob_coffee_last__ = ")
      (end-of-buffer)
      (insert "
__ob_coffee_log__ = (obj)->
    console.log obj
    process.stdout.write('\u2029') and undefined
if 'function' is typeof __ob_coffee_last__.then
    __ob_coffee_last__.then __ob_coffee_log__, __ob_coffee_log__
    console.log \"Promise:\"
else
    __ob_coffee_log__ __ob_coffee_last__"))
    (buffer-string)))

(defun ob-coffee-eval (session body)
  (ob-coffee-eval-in-repl session body))

(defun ob-coffee-ensure-session (session)
  (let ((name (format "*coffee-%s*" session)))
    (unless (and (get-process name)
                 (process-live-p (get-process name)))
      (with-current-buffer (get-buffer-create name)
        (make-local-variable 'process-environment)
        (setq process-environment
              (cons "NODE_NO_READLINE=1" process-environment))
        (start-process name name "node" ob-coffee-path-to-repl-js))
      (sit-for 0.5)
      (set-process-filter (get-process name) 'ob-coffee-process-filter))))

(defun ob-coffee-process-filter (process output)
  (setq ob-coffee-process-output (concat ob-coffee-process-output output)))

(defun ob-coffee-wait ()
  (while (not (string-match-p "\x2029" ob-coffee-process-output))
    (sit-for 0.2)))

(defun ob-coffee-eval-in-repl (session body)
  (let ((name (format "*coffee-%s*" session)))
    (setq ob-coffee-process-output nil)
    (process-send-string name (format "%s\n" body))
    (accept-process-output (get-process name) nil nil 1)
    (ob-coffee-wait)
    (message
     (replace-regexp-in-string "\x2029" "" ob-coffee-process-output))))

(provide 'ob-coffee)
;;; ob-coffee.el ends here
