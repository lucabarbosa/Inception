NAME = inception

SRC_DIR = ./srcs
DOCKER_COMPOSE = $(SRC_DIR)/docker-compose.yml

all: setup up

setup:
	@grep -q "lbento.42.fr" /etc/hosts || echo "127.0.0.1 lbento.42.fr" | sudo tee -a /etc/hosts > /dev/null
	@sudo mkdir -p /home/lbento/data/wp_data
	@sudo mkdir -p /home/lbento/data/db_data

bonus: all

up:
	docker compose -p $(NAME) -f $(DOCKER_COMPOSE) up --build -d

down:
	docker compose -p $(NAME) -f $(DOCKER_COMPOSE) down

stop:
	docker compose -p $(NAME) -f $(DOCKER_COMPOSE) stop

start:
	docker compose -p $(NAME) -f $(DOCKER_COMPOSE) start
	
logs:
	docker compose -p $(NAME) -f $(DOCKER_COMPOSE) logs -f

ps:
	docker compose -p $(NAME) -f $(DOCKER_COMPOSE) ps

clean:
	docker compose -p $(NAME) -f $(DOCKER_COMPOSE) down --rmi all -v --remove-orphans

fclean: clean
	docker system prune -af --volumes
	@sudo rm -rf /home/lbento/data/wp_data
	@sudo rm -rf /home/lbento/data/db_data

re: clean all

.PHONY: all bonus setup up down stop start logs ps clean fclean re