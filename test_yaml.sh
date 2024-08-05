CONFIG_FILE=config.yml

read_yaml() {
    python -c "import yaml
with open('$1', 'r') as file:
    data = yaml.safe_load(file)
for key, value in data.items():
    print(f'{key.upper()}={value}')
"
}

read_yaml $CONFIG_FILE
