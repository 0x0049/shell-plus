;;; shell+-test.el --- Tests for shell+. -*- lexical-binding: t -*-

;; Copyright (c) 2020 0x0049
;;
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

;;; Code:

(require 'ert)
(require 'with-simulated-input)
(require 'shell+)

(ert-deftest shell+-eshell-test ()
  "Test that eshell is opened."
  (shell+--cleanup)
  (shell+-eshell)
  (should (string= "*eshell*" (buffer-name)))
  (switch-to-buffer " *temp*")
  (shell+-eshell)
  (should (string= "*eshell*" (buffer-name)))
  (should (eq 1 (length (shell+--get-eshell-buffers)))))

(ert-deftest shell+-eshell-unique-test ()
  "Test that a eshell buffers have unique history files."
  (shell+--cleanup)
  (shell+-eshell "test")
  (should (string= "*eshell test*" (buffer-name)))
  (should (eq 1 (length (shell+--get-eshell-buffers))))
  (should (string= (expand-file-name "*eshell-test*" eshell-directory-name) eshell-history-file-name))

  (shell+-eshell)
  (should (string= "*eshell*" (buffer-name)))
  (should (eq 2 (length (shell+--get-eshell-buffers))))
  (should (string= (expand-file-name "*eshell*" eshell-directory-name) eshell-history-file-name)))

(ert-deftest shell+-eshell-manual-test()
  "Test that manual suffixes and history files work."
  (shell+--cleanup)
  (with-simulated-input "suffix-1 RET //path/to/file-1 RET"
    (shell+-eshell nil t))
  (should (string= "*eshell suffix-1*" (buffer-name)))
  (should (string= "/path/to/file-1" eshell-history-file-name))

  (with-simulated-input "//path/to/file-2/ RET"
    (shell+-eshell "suffix-2" t))
  (should (string= "/path/to/file-2/" eshell-history-file-name))
  (should (string= "*eshell suffix-2*" (buffer-name)))
  (should (equal '("suffix-2" "suffix-1") shell+--known-eshell-suffixes))

  ;; Since the buffer already exists it shouldn't ask for the history file.
  (with-simulated-input "suffix-1 RET" (shell+-eshell nil t))
  (should (string= "*eshell suffix-1*" (buffer-name)))
  (should (string= "/path/to/file-1" eshell-history-file-name))

  (shell+-eshell "suffix-2" t)
  (should (string= "/path/to/file-2/" eshell-history-file-name))
  (should (string= "*eshell suffix-2*" (buffer-name))))

(ert-deftest shell+-eshell-no-unique-test ()
  "Test that a eshell buffers do *not* have unique history files."
  (shell+--cleanup)
  (setq shell+-eshell-unique-history nil)
  (shell+-eshell "test")
  (should (string= "*eshell test*" (buffer-name)))
  (should (eq 1 (length (shell+--get-eshell-buffers))))
  (should (string= (expand-file-name "history" eshell-directory-name) eshell-history-file-name))

  (shell+-eshell)
  (should (string= "*eshell*" (buffer-name)))
  (should (eq 2 (length (shell+--get-eshell-buffers))))
  (should (string= (expand-file-name "history" eshell-directory-name) eshell-history-file-name)))

(provide 'shell+-test)

;;; shell+-test.el ends here
