;;; shell+.el --- Shell enhancements for Emacs. -*- lexical-binding: t -*-

;; Copyright (c) 2020 0x0049

;; Author: 0x0049 <dev@0x0049.me>
;; URL: https://github.com/0x0049/shell-plus
;; Keywords: shell
;; Version: 1.0

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
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

;; shell+ adds functionality around shell buffers.

;;; Code:

(require 'eshell)
(require 'esh-mode)
(require 'em-hist)
(require 'em-dirs)
(require 'cl-lib)

(defgroup shell+ nil
  "Shell enhancements."
  :group 'applications)

(defcustom shell+-eshell-unique-history t
  "Enable unique history for eshell buffers."
  :type 'boolean
  :group 'shell+)

(defcustom shell+-lock-command "loginctl lock-session"
  "Command for locking the screen."
  :type 'string
  :group 'shell+)

(defcustom shell+-hibernate-command "systemctl hibernate"
  "Command for hibernating."
  :type 'string
  :group 'shell+)

(defcustom shell+-hibernate-hook nil
  "Hook run bfore hibernating."
  :type 'hook
  :group 'shell+)

(defvar shell+--eshell-history-directory-name nil "Full path of the eshell history directory.")

;; This is to make it less annoying to switch to manually suffixed buffers.
(defvar shell+--known-eshell-suffixes nil "Manually typed eshell suffixes.")

;;;###autoload
(defun shell+-lock ()
  "Lock the screen."
  (interactive)
  (shell+-async-shell-no-buffer shell+-lock-command))

;;;###autoload
(defun shell+-hibernate ()
  "Hibernate the system."
  (interactive)
  (run-hooks 'shell+-hibernate-hook)
  (shell+-async-shell-no-buffer shell+-hibernate-command))

;;;###autoload
(defun shell+-prompt (prompt &rest options)
  "Prompt for input using PROMPT and OPTIONS.

OPTIONS is a plist that can contain :choices, :require,
:selected, and :default. If :choices is set `completing-read'
will be used. If no choices are set then :selected and :default
will be ignored."
  (let ((prompt (concat prompt ": "))
        (choices (plist-get options :choices)))
    (if choices
        (completing-read
         prompt
         choices
         nil
         (plist-get options :require)
         (plist-get options :selected)
         nil
         (plist-get options :default))
      (read-from-minibuffer prompt))))

;;;###autoload
(defun shell+-async-shell-no-buffer (&rest args)
  "Execute ARGS asynchronously without a buffer.

ARGS are simply concatenated with spaces.

If no ARGS are provided, prompt for the command."
  (interactive (list (read-shell-command "$ ")))
  (let ((command (mapconcat 'identity args " " )))
    (start-process-shell-command command nil command)))

;;;###autoload
(defun shell+-async-shell-buffer (&rest args)
  "Execute ARGS asynchronously with a buffer.

ARGS are simply concatenated with spaces.

If no ARGS are provided, prompt for the command."
  (interactive (list (read-shell-command "$ ")))
  (let* ((command (mapconcat
                   #'(lambda (a)
                       (if (numberp a)
                           (number-to-string a)
                         a))
                   args " " ))
         (output-buffer (concat "*" command "*")))
    (async-shell-command command output-buffer)))

;;;###autoload
(defalias 'eshell/async #'shell+-async-shell-buffer)

(defun shell+--find-inactive-eshell-buffer (prefix)
  "Search for an inactive eshell buffer prefixed with PREFIX."
  (cl-find-if
   (lambda (buffer)
     (when (string-prefix-p prefix (or (buffer-name buffer) ""))
       (with-current-buffer buffer
         (and (eq major-mode 'eshell-mode) (not (eshell-interactive-process))))))
   (buffer-list)))

(defun shell+--eshell-set-history-file ()
  "Set history file for the buffer."
  (when shell+--eshell-history-directory-name
    (setq-local eshell-history-file-name
                (expand-file-name
                 (replace-regexp-in-string " " "-" (buffer-name))
                 shell+--eshell-history-directory-name))))

(add-hook 'eshell-hist-load-hook #'shell+--eshell-set-history-file)

;;;###autoload
(defun shell+-eshell (&optional suffix arg)
  "Open an existing `eshell' buffer or a new one if all are busy.

SUFFIX is used in the buffer name if provided.

With \\[universal-argument] or ARG, ask for the history directory
and for a suffix if one wasn't provided."
  (let* ((eshell-suffix (or suffix
                            (and arg (shell+-prompt "Suffix"
                                                    :choices shell+--known-eshell-suffixes
                                                    :require))))
         (eshell-buffer-name (if eshell-suffix (format "*eshell %s*" eshell-suffix) "*eshell*"))
         (eshell-buffer (shell+--find-inactive-eshell-buffer eshell-buffer-name)))
    (if eshell-buffer
        (switch-to-buffer eshell-buffer)
      (let ((shell+--eshell-history-directory-name
             (when shell+-eshell-unique-history
               (if arg
                   (expand-file-name
                    (substring-no-properties
                     (read-directory-name "History directory: " eshell-directory-name)))
                 eshell-directory-name))))
        (when (and arg eshell-suffix)
          (add-to-list 'shell+--known-eshell-suffixes eshell-suffix))
        (eshell t)))))

;;;###autoload
(defun shell+-eshell-cd (&optional arg)
  "Open an existing `eshell' buffer or a new one if all are busy.

Then cd to the directory of the current buffer.

With \\[universal-argument] or ARG, ask for history file path and
suffix for the buffer name."
  (interactive "P")
  (let ((dir default-directory))
    (shell+-eshell nil arg)
    (unless (string= dir (file-name-as-directory (eshell/pwd)))
      (eshell/cd dir)
      (goto-char (point-max))
      (eshell-send-input nil t))))

;;;###autoload
(defun shell+-eshell-insert-history ()
  "Interactively insert eshell history.

Use the current command line text (if any) as the initial input.

Call `evil-insert' after inserting a command if it exists."
  (interactive)
  (let ((start-point nil) (end-point nil))
    (save-excursion (goto-char (point-max))
                    (setq start-point (eshell-bol))
                    (setq end-point (point-at-eol)))
    (let* ((input (buffer-substring-no-properties start-point end-point))
           (history (and (bound-and-true-p eshell-history-ring)
                         (delete-dups (ring-elements eshell-history-ring))))
           (command (shell+-prompt "History" :choices history :selected input)))
      (when command
        (delete-region start-point end-point)
        (goto-char (point-max))
        (insert command)
        (when (fboundp 'evil-insert) (evil-insert 1))
        (end-of-line)))))

(provide 'shell+)

;;; shell+.el ends here
