;;; helm-fd.el --- Emacs/Helm interface to fd             -*- lexical-binding: t; -*-

;; Copyright (C) 2017

;; Author: Ian Pickering <ipickering2@gmail.com>
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Provides a Helm interface to the "fd" utility.

;;; Code:

(require 'cl-lib)
(require 'helm)

(defcustom helm-fd-base-command "fd"
  "Base command of `fd'."
  :type 'string)

(defcustom helm-fd-command-option nil
  "Command line option of `fd'. This is appended after `helm-fd-base-command'."
  :type 'string)

(defvar helm-fd--command nil)

(defvar helm-fd--helm-history '())
(defvar helm-fd--ignore-case nil)
(defvar helm-fd--default-directory nil)
(defvar helm-fd--original-window nil)

(defun helm-fd--ignore-case-p (cmds input)
  "Determines if case should be ignored in the candidate output."
  (cl-loop for cmd in cmds
           when (member cmd '("-i" "--ignore-case"))
           return t

           when (member cmd '("-s" "--case-sensitive"))
           return nil

           finally
           return (let ((case-fold-search nil))
                    (not (string-match-p "[A-Z]" input)))))


(defsubst helm-fd--init-state ()
  (setq helm-fd--original-window (selected-window)))

(defsubst helm-fd--helm-header (dir)
  (concat "Search in " (abbreviate-file-name dir)))

(defvar helm-fd-map
  (let ((map (make-sparse-keymap)))
    ;(set-keymap-parent map helm-ag-map)
    ;define-key map (kbd "C-l") 'helm-ag--do-ag-up-one-level)
    ;define-key map (kbd "C-c ?") 'helm-ag--do-ag-help)
    map)
  "Keymap for `helm-fd'.")

(defun helm-fd--helm ()
  (let ((search-dir helm-fd--default-directory))
    ;(helm-attrset 'name (helm-fd--helm-header search-dir))
    (helm :sources '(helm-source-fd) :buffer "*helm-fd*" :keymap helm-fd-map
          :history helm-fd--helm-history)))

(defun helm-fd--parse-options-and-query (pattern)
  (cons nil pattern))

(defun helm-fd--construct-do-fd-command (pattern)
  (let* ((opt-query (helm-fd--parse-options-and-query pattern))
         (options (car opt-query))
         (query (cdr opt-query))
         (has-query (not (string= query ""))))
    (when has-query
      (let ((cmd (helm-fd--do-fd-command)))
       (append (cdr cmd)
                options
                (and has-query (list query))
                (car cmd))))))

(defun helm-fd--do-fd-command ()
  (let ((args (split-string helm-fd-base-command nil t)))
    (when helm-fd-command-option
      (let ((fd-options (split-string helm-fd-command-option nil t)))
        (setq args (append args fd-options))))
    (cons (list helm-fd--default-directory)
          args)))

(defun helm-fd--propertize-candidates (input)
  input)

(defun helm-fd--do-fd-propertize (input)
  (with-helm-window
    (helm-fd--propertize-candidates input)))

(defun helm-fd--do-fd-candidate-process ()
  "Helm candidate process for helm-fd."
  (let ((cmd-args (helm-fd--construct-do-fd-command helm-pattern)))
    (when cmd-args
      (let ((proc (apply #'start-process "helm-do-fd" nil cmd-args)))
        (setq helm-fd--ignore-case (helm-ag--ignore-case-p cmd-args helm-pattern))
        proc))))

(defun helm-fd--action-find-file (candidate)
  (find-file candidate))

(defun helm-fd--action-find-file-other-window (candidate)
  (find-file-other-window candidate))

(defvar helm-fd--actions
  (helm-make-actions
   "Open file"              #'find-file
   "Open file other window" #'find-file-other-window
                                        ;"Save results in buffer" #'helm-ag--action-save-buffer
                                        ;"Edit search results"    #'helm-ag--edit
   ))

(defvar helm-source-fd
  (helm-build-async-source "fd"
    :init 'helm-fd--do-fd-set-command
    :candidates-process 'helm-fd--do-fd-candidate-process
    :persistent-action  'helm-fd--persistent-action
    :action helm-fd--actions
    :nohighlight t
    :requires-pattern 3
    :candidate-number-limit 9999
    :keymap helm-fd-map
    :follow (and helm-follow-mode-persistent 1)))

;;;###autoload
(defun helm-fd-this-directory ()
  "Run fd inside the current directory."
  (interactive)
  (helm-fd--init-state)
  (helm-aif (buffer-file-name)
      (helm-fd default-directory)))

;;;###autoload
(defun helm-fd (&optional basedir)
  "Run fd in the specified directory."
  (interactive)
  (require 'helm-mode)
  (helm-fd--init-state)
  (let ((helm-fd--default-directory
         (or basedir (helm-basedir
                      (helm-read-file-name
                       "Search in directory: "
                       :default default-directory
                       :must-match t)))))
    (helm-fd--helm)))

(provide 'helm-fd)
;;; helm-fd.el ends here
