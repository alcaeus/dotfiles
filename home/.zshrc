# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{inputrc,path,zshprompt,exports,aliases,functions,extra,completions}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:$(brew --prefix)/share/zsh-completions:${FPATH}"

  autoload -Uz compinit
  compinit
  setopt always_to_end
fi
