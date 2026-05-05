# Módulo SystemVerilog de Im2Col

## Visão Geral

O módulo `img2row` implementa a operação **Im2Col** (*image to column*) em hardware, transformando uma janela de imagem 2D em uma matriz de colunas usada tipicamente como pré-processamento para convolução via multiplicação de matrizes (GEMM). É parametrizável em largura de dados, tamanho do kernel e tamanho da janela de entrada.

## Parâmetros

| Parâmetro      | Tipo       | Padrão | Descrição                                              |
|----------------|------------|--------|--------------------------------------------------------|
| `WIDTH`        | `integer`  | `4`    | Largura em bits de cada pixel                          |
| `SIZE_KER`     | `integer`  | `3`    | Dimensão do kernel (ex.: 3 para kernel 3×3)            |
| `SIZE_WINDOW`  | `integer`  | `6`    | Dimensão da janela de entrada (ex.: 6 para imagem 6×6) |

### Parâmetros Locais (calculados automaticamente)

| Parâmetro local | Fórmula                                  | Descrição                                      |
|-----------------|------------------------------------------|------------------------------------------------|
| `OUT_SIZE`      | `SIZE_WINDOW - SIZE_KER + 1`             | Dimensão da saída (número de posições de patch) |
| `OUT_SIZE_NORM` | `$clog2(2^(OUT_SIZE × OUT_SIZE))`        | Largura do índice para endereçar todos os patches|

## Interface de Sinais

| Sinal       | Direção  | Largura                                  | Descrição                                              |
|-------------|----------|------------------------------------------|--------------------------------------------------------|
| `clk`       | Entrada  | 1                                        | Clock do sistema                                       |
| `rst_n_sync`| Entrada  | 1                                        | Reset síncrono ativo em nível baixo                    |
| `valid_i`   | Entrada  | 1                                        | Indica que `img` contém dados válidos prontos para processar |
| `ready_o`   | Saída    | 1                                        | Módulo pronto para receber nova imagem                 |
| `rvalid_o`  | Saída    | 1                                        | Resultado disponível em `colout`                       |
| `rready_i`  | Entrada  | 1                                        | Consumidor pronto para aceitar o resultado             |
| `img`       | Entrada  | `[WIDTH-1:0][SIZE_WINDOW-1:0][SIZE_WINDOW-1:0]` | Janela de imagem de entrada                  |
| `colout`    | Saída    | `[WIDTH-1:0][OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0]` | Matriz Im2Col resultante              |

O handshake de entrada segue o protocolo **valid/ready**, assim como o de saída (**rvalid/rready**), compatível com interfaces AXI-Stream.

## Funcionamento

### Operação Im2Col

Para cada posição `(row, col)` válida na janela de entrada, o módulo extrai o patch de tamanho `SIZE_KER × SIZE_KER` e o armazena como uma coluna na matriz de saída `colout`. O índice do patch é calculado como:

```
patch_idx = OUT_SIZE × row + col
```

A extração dos pixels do patch é feita combinacionalmente via `generate`:

```systemverilog
for (i_win = 0; i_win < SIZE_KER; i_win++)
    for (j_win = 0; j_win < SIZE_KER; j_win++)
        window[i_win*SIZE_KER + j_win] = img[i_win + row][j_win + col];
```

### Máquina de Estados (FSM)

O módulo possui três estados:

```
IDLE ──(valid_i=1)──► TRANSFORM_IMAGE2COL ──(fim varredura)──► DONE ──(rready_i=1)──► IDLE
```

| Estado                | Comportamento                                                                    |
|-----------------------|----------------------------------------------------------------------------------|
| `IDLE`                | Aguarda `valid_i`. `ready_o=1`, `rvalid_o=0`                                     |
| `TRANSFORM_IMAGE2COL` | Varre todas as posições `(row, col)`, gravando cada patch em `colout`. `ready_o=0`, `rvalid_o=0` |
| `DONE`                | Sinaliza resultado pronto com `rvalid_o=1`. Aguarda `rready_i` para voltar ao `IDLE` |

### Lógica de Avanço de Posição

Dentro do estado `TRANSFORM_IMAGE2COL`, o par `(row, col)` avança da seguinte forma:

| `is_row_oob` | `is_col_oob` | Ação                   |
|:---:|:---:|------------------------|
| 0 | 0 | Incrementa `col`       |
| 0 | 1 | Incrementa `row`, reseta `col` |
| 1 | 0 | Incrementa `col`       |
| 1 | 1 | Mantém posição (transição para `DONE`) |

## Exemplo de Uso

```systemverilog
img2row #(
    .WIDTH      (8),
    .SIZE_KER   (3),
    .SIZE_WINDOW(5)
) u_img2row (
    .clk         (clk),
    .rst_n_sync  (rst_n),
    .valid_i     (data_valid),
    .ready_o     (module_ready),
    .rvalid_o    (result_valid),
    .rready_i    (downstream_ready),
    .img         (input_image),
    .colout      (col_matrix)
);
```

Com `SIZE_WINDOW=5` e `SIZE_KER=3`, a saída terá `OUT_SIZE = 3`, gerando 9 patches de 9 pixels cada.

## Limitações e Observações

- O módulo processa **uma janela por vez**; uma nova imagem só pode ser enviada após o consumidor aceitar o resultado (`rready_i=1`).
- O campo `patch_idx` é registrado com um ciclo de atraso em relação a `patch_idx_next`; confirme o alinhamento temporal ao integrar com outros módulos.
- A lógica de avanço de coluna quando `is_row_oob=1` e `is_col_oob=0` incrementa `col` mesmo fora dos limites de linha — verifique se este comportamento é intencional para o caso de uso específico.
- O módulo foi projetado e testado com `WIDTH=4`, `SIZE_KER=3` e `SIZE_WINDOW=6`.

## Informações do Arquivo

| Campo        | Valor                                  |
|--------------|----------------------------------------|
| Autor        | Valmir F. Silva                        |
| Contato      | valmir.silva@ee.ufcg.edu.br            |
| Organização  | UFCG                                   |
| Versão       | 1.0                                    |
| Criado em    | 05/03/2026                             |
