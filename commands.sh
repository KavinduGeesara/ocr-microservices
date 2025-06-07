sudo apt-get update
sudo apt-get upgrade
curl -sSL https://install.python-poetry.org | python3 -
export PATH="/home/thsklk/.local/bin:$PATH"
source ~/.bashrc
poetry --version

sudo apt-get install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses-dev xz-utils tk-dev libffi-dev liblzma-dev python3-openssl git
git clone https://github.com/pyenv/pyenv.git ~/.pyenv
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc
pyenv --version
pyenv install 3.11


sudo apt-get install tesseract-ocr 


# got to directory that model.py, api-gateway.py and pyproject.toml are in
pyenv local 3.11
poetry install --no-root
poetry env activate
poetry run python model.py &
poetry run python api-gateway.py &


curl http://localhost:8080/metrics